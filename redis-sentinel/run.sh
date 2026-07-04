#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

# Read configuration
MASTER_NAME=$(bashio::config 'master_name')
MASTER_HOST=$(bashio::config 'master_host')
MASTER_PORT=$(bashio::config 'master_port')
MASTER_PASSWORD=$(bashio::config 'master_password')
QUORUM=$(bashio::config 'quorum')
DOWN_AFTER=$(bashio::config 'down_after_ms')
FAILOVER_TIMEOUT=$(bashio::config 'failover_timeout')
LOG_LEVEL=$(bashio::config 'log_level')

bashio::log.blue "================================================"
bashio::log.blue " Redis Sentinel (tiebreaker)"
bashio::log.blue "================================================"
bashio::log.cyan "Master name:       ${MASTER_NAME}"
bashio::log.cyan "Master host:       ${MASTER_HOST}:${MASTER_PORT}"
bashio::log.cyan "Quorum:            ${QUORUM}"
bashio::log.cyan "Down-after:        ${DOWN_AFTER}ms"
bashio::log.cyan "Failover timeout:  ${FAILOVER_TIMEOUT}ms"
bashio::log.cyan "Log level:         ${LOG_LEVEL}"
bashio::log.blue "================================================"

# Map log level
case "${LOG_LEVEL}" in
    DEBUG)   REDIS_LOG="debug" ;;
    INFO)    REDIS_LOG="notice" ;;
    WARNING) REDIS_LOG="warning" ;;
    ERROR)   REDIS_LOG="warning" ;;
    *)       REDIS_LOG="notice" ;;
esac

# Generate sentinel config
cat > /etc/redis/sentinel.conf << EOF
port 26379
bind 0.0.0.0
daemonize no
loglevel ${REDIS_LOG}
logfile ""

sentinel monitor ${MASTER_NAME} ${MASTER_HOST} ${MASTER_PORT} ${QUORUM}
sentinel down-after-milliseconds ${MASTER_NAME} ${DOWN_AFTER}
sentinel failover-timeout ${MASTER_NAME} ${FAILOVER_TIMEOUT}
sentinel parallel-syncs ${MASTER_NAME} 1
sentinel resolve-hostnames no
EOF

# Add auth if password is set
if [ -n "${MASTER_PASSWORD}" ]; then
    echo "sentinel auth-pass ${MASTER_NAME} ${MASTER_PASSWORD}" >> /etc/redis/sentinel.conf
fi

bashio::log.green "Starting Redis Sentinel — monitoring '${MASTER_NAME}' at ${MASTER_HOST}:${MASTER_PORT}..."

# Run sentinel in foreground
exec redis-sentinel /etc/redis/sentinel.conf
