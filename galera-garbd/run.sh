#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

# Read configuration
CLUSTER_NAME=$(bashio::config 'cluster_name')
CLUSTER_ADDRESS=$(bashio::config 'cluster_address')
LOG_LEVEL=$(bashio::config 'log_level')

bashio::log.blue "================================================"
bashio::log.blue " Galera Arbitrator (garbd)"
bashio::log.blue "================================================"
bashio::log.cyan "Cluster name:    ${CLUSTER_NAME}"
bashio::log.cyan "Cluster address: ${CLUSTER_ADDRESS}"
bashio::log.cyan "Log level:       ${LOG_LEVEL}"
bashio::log.blue "================================================"

# Map log level to garbd format
case "${LOG_LEVEL}" in
    DEBUG)   GARBD_LOG="7" ;;
    INFO)    GARBD_LOG="6" ;;
    WARNING) GARBD_LOG="4" ;;
    ERROR)   GARBD_LOG="3" ;;
    *)       GARBD_LOG="6" ;;
esac

bashio::log.green "Starting garbd — joining Galera cluster '${CLUSTER_NAME}'..."

# Run garbd in foreground
# garbd participates in Galera group communication (port 4567)
# It votes in quorum but stores no data
exec garbd \
    --group "${CLUSTER_NAME}" \
    --address "${CLUSTER_ADDRESS}" \
    --log "/dev/stdout" \
    --option "base_port=4567; evs.keepalive_period=PT1S; evs.suspect_timeout=PT10S; evs.inactive_timeout=PT30S"
