#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

# Read configuration
REDIS_PRIMARY_HOST=$(bashio::config 'redis_primary_host')
REDIS_PRIMARY_PORT=$(bashio::config 'redis_primary_port')
REDIS_SENTINEL_PORT=$(bashio::config 'redis_sentinel_port')
REDIS_QUORUM=$(bashio::config 'redis_quorum')
REDIS_DOWN_AFTER=$(bashio::config 'redis_down_after_ms')
REDIS_FAILOVER_TIMEOUT=$(bashio::config 'redis_failover_timeout')
MARIADB_PRIMARY=$(bashio::config 'mariadb_primary_host')
MARIADB_STANDBY=$(bashio::config 'mariadb_standby_host')
MARIADB_PORT=$(bashio::config 'mariadb_port')
MARIADB_HEALTH_PORT=$(bashio::config 'mariadb_health_port')
LOG_LEVEL=$(bashio::config 'log_level')

bashio::log.blue "================================================"
bashio::log.blue " Database Quorum (Sentinel + Arbiter)"
bashio::log.blue "================================================"
bashio::log.cyan "Redis primary:     ${REDIS_PRIMARY_HOST}:${REDIS_PRIMARY_PORT}"
bashio::log.cyan "Redis Sentinel:    :${REDIS_SENTINEL_PORT} (quorum: ${REDIS_QUORUM})"
bashio::log.cyan "MariaDB primary:   ${MARIADB_PRIMARY}:${MARIADB_PORT}"
bashio::log.cyan "MariaDB standby:   ${MARIADB_STANDBY}:${MARIADB_PORT}"
bashio::log.cyan "MariaDB arbiter:   :${MARIADB_HEALTH_PORT}"
bashio::log.cyan "Log level:         ${LOG_LEVEL}"
bashio::log.blue "================================================"

# --- Redis Sentinel Configuration ---
mkdir -p /data/sentinel

cat > /data/sentinel/sentinel.conf << EOF
port ${REDIS_SENTINEL_PORT}
daemonize no
pidfile /run/redis-sentinel.pid
logfile ""
dir /data/sentinel

sentinel monitor homelab-redis ${REDIS_PRIMARY_HOST} ${REDIS_PRIMARY_PORT} ${REDIS_QUORUM}
sentinel down-after-milliseconds homelab-redis ${REDIS_DOWN_AFTER}
sentinel failover-timeout homelab-redis ${REDIS_FAILOVER_TIMEOUT}
sentinel parallel-syncs homelab-redis 1
EOF

# --- MariaDB Arbiter ---
# Start the MariaDB health arbiter in the background
bashio::log.green "Starting MariaDB arbiter on port ${MARIADB_HEALTH_PORT}..."
/mariadb-arbiter.sh "${MARIADB_PRIMARY}" "${MARIADB_STANDBY}" "${MARIADB_PORT}" "${MARIADB_HEALTH_PORT}" &

# --- Start Redis Sentinel ---
bashio::log.green "Starting Redis Sentinel on port ${REDIS_SENTINEL_PORT}..."
exec redis-sentinel /data/sentinel/sentinel.conf
