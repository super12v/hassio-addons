#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

# Read configuration
REDIS_PRIMARY_HOST=$(bashio::config 'redis_primary_host')
REDIS_PRIMARY_PORT=$(bashio::config 'redis_primary_port')
SENTINEL_PORT=$(bashio::config 'sentinel_port')
QUORUM=$(bashio::config 'quorum')
DOWN_AFTER=$(bashio::config 'down_after_ms')
FAILOVER_TIMEOUT=$(bashio::config 'failover_timeout')
LOG_LEVEL=$(bashio::config 'log_level')

bashio::log.blue "================================================"
bashio::log.blue " Redis Sentinel (tiebreaker)"
bashio::log.blue "================================================"
bashio::log.cyan "Redis primary:  ${REDIS_PRIMARY_HOST}:${REDIS_PRIMARY_PORT}"
bashio::log.cyan "Sentinel port:  ${SENTINEL_PORT}"
bashio::log.cyan "Quorum:         ${QUORUM}"
bashio::log.cyan "Down after:     ${DOWN_AFTER}ms"
bashio::log.cyan "Failover timeout: ${FAILOVER_TIMEOUT}ms"
bashio::log.cyan "Log level:      ${LOG_LEVEL}"
bashio::log.blue "================================================"

# Generate sentinel config
mkdir -p /data/sentinel

cat > /data/sentinel/sentinel.conf << EOF
port ${SENTINEL_PORT}
daemonize no
pidfile /run/redis-sentinel.pid
logfile ""
dir /data/sentinel

sentinel monitor homelab-redis ${REDIS_PRIMARY_HOST} ${REDIS_PRIMARY_PORT} ${QUORUM}
sentinel down-after-milliseconds homelab-redis ${DOWN_AFTER}
sentinel failover-timeout homelab-redis ${FAILOVER_TIMEOUT}
sentinel parallel-syncs homelab-redis 1
EOF

bashio::log.green "Starting Redis Sentinel on port ${SENTINEL_PORT}..."
exec redis-sentinel /data/sentinel/sentinel.conf
