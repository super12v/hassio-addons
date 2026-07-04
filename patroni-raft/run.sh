#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

# Read configuration from add-on options
SELF_ADDR=$(bashio::config 'self_addr')
SCOPE=$(bashio::config 'scope')
NAMESPACE=$(bashio::config 'namespace')
LOG_LEVEL=$(bashio::config 'log_level')
REPL_USER=$(bashio::config 'replication_username')
REPL_PASS=$(bashio::config 'replication_password')
SU_USER=$(bashio::config 'superuser_username')
SU_PASS=$(bashio::config 'superuser_password')
PG_VERSION=$(bashio::config 'pg_version')
RESTAPI_USER=$(bashio::config 'restapi_username')
RESTAPI_PASS=$(bashio::config 'restapi_password')
RAFT_PASS=$(bashio::config 'raft_password')

bashio::log.blue "================================================"
bashio::log.blue " Patroni Raft Voter (tiebreaker)"
bashio::log.blue "================================================"
bashio::log.cyan "Self address: ${SELF_ADDR}"
bashio::log.cyan "Scope:        ${SCOPE}"
bashio::log.cyan "Namespace:    ${NAMESPACE}"
bashio::log.cyan "Log level:    ${LOG_LEVEL}"
bashio::log.blue "================================================"

# Extract IP from self_addr (format: ip:port)
SELF_IP="${SELF_ADDR%:*}"

# Build partner_addrs YAML list
PARTNER_YAML=""
for addr in $(bashio::config 'partner_addrs'); do
    PARTNER_YAML="${PARTNER_YAML}    - ${addr}
"
done

# Prepare PG data dir (Patroni manages a real but idle PG instance)
mkdir -p /data/pgdata /data/raft /run/postgresql
chown -R postgres:postgres /data/pgdata /data/raft /run/postgresql
chmod 700 /data/pgdata

# If existing data was created by a different PG version, wipe it
if [ -f /data/pgdata/PG_VERSION ]; then
    DATA_PG=$(cat /data/pgdata/PG_VERSION)
    if [ "$PG_VERSION" != "$DATA_PG" ]; then
        bashio::log.warning "PG version mismatch (data: ${DATA_PG}, configured: ${PG_VERSION}) — wiping data dir"
        rm -rf /data/pgdata/*
    fi
fi

# Find postgresql bin dir for the configured version
PG_BIN="/usr/libexec/postgresql${PG_VERSION}"
if [ ! -d "$PG_BIN" ]; then
    PG_BIN="/usr/bin"
fi

# Detect config change — if partner_addrs or scope changed, Raft state is stale
# and must be wiped. Otherwise the node tries to rejoin a non-existent cluster.
CONFIG_HASH=$(echo "${SCOPE}:${SELF_ADDR}:$(bashio::config 'partner_addrs')" | md5sum | cut -d' ' -f1)
SAVED_HASH=""
if [ -f /data/raft/.config_hash ]; then
    SAVED_HASH=$(cat /data/raft/.config_hash)
fi

if [ "${CONFIG_HASH}" != "${SAVED_HASH}" ]; then
    bashio::log.warning "Configuration changed (partner_addrs, scope, or self_addr). Wiping stale Raft state."
    rm -rf /data/raft/*
    rm -rf /data/pgdata/*
    mkdir -p /data/raft
    echo "${CONFIG_HASH}" > /data/raft/.config_hash
    bashio::log.info "Raft state cleared. Node will rejoin cluster fresh."
else
    bashio::log.info "Configuration unchanged. Preserving existing Raft state."
fi

# Generate patroni.yml
# This node runs a real PostgreSQL instance but with nofailover=true,
# nosync=true, noloadbalance=true — it only participates in Raft votes.
# PostgreSQL will start but accept no connections from outside.
cat > /etc/patroni.yml << EOF
scope: ${SCOPE}
namespace: ${NAMESPACE}
name: ha-tiebreaker

log:
  level: ${LOG_LEVEL}

raft:
  data_dir: /data/raft
  self_addr: ${SELF_ADDR}
  partner_addrs:
${PARTNER_YAML}
restapi:
  listen: "0.0.0.0:8008"
  connect_address: "${SELF_IP}:8008"
EOF

# Add REST API auth if configured
if [ -n "${RESTAPI_USER}" ] && [ -n "${RESTAPI_PASS}" ]; then
    cat >> /etc/patroni.yml << EOF
  authentication:
    username: ${RESTAPI_USER}
    password: ${RESTAPI_PASS}
EOF
fi

# Add Raft password if configured
if [ -n "${RAFT_PASS}" ]; then
    sed -i "/^raft:/a\\  password: ${RAFT_PASS}" /etc/patroni.yml
fi

cat >> /etc/patroni.yml << EOF

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: false
      use_slots: true
      parameters:
        listen_addresses: "127.0.0.1"
        max_connections: 5

  initdb:
    - encoding: UTF8
    - data-checksums

  pg_hba:
    - local all all peer
    - host replication replicator 127.0.0.1/32 trust

postgresql:
  listen: "127.0.0.1:5432"
  connect_address: "${SELF_IP}:5432"
  data_dir: /data/pgdata
  bin_dir: ${PG_BIN}
  pgpass: /tmp/pgpass0
  authentication:
    replication:
      username: ${REPL_USER}
      password: ${REPL_PASS}
    superuser:
      username: ${SU_USER}
      password: ${SU_PASS}
  parameters:
    listen_addresses: "127.0.0.1"
    max_connections: 5

tags:
  nofailover: true
  noloadbalance: true
  clonefrom: false
  nosync: true
EOF

mkdir -p /data/raft

bashio::log.info "PG bin: ${PG_BIN}"
bashio::log.info "Starting Patroni Raft voter..."
chown postgres:postgres /etc/patroni.yml
exec su-exec postgres patroni /etc/patroni.yml
