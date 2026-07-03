#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

# Read configuration
MARIADB_PRIMARY=$(bashio::config 'mariadb_primary_host')
MARIADB_STANDBY=$(bashio::config 'mariadb_standby_host')
MARIADB_PORT=$(bashio::config 'mariadb_port')
HEALTH_PORT=$(bashio::config 'health_port')
CHECK_INTERVAL=$(bashio::config 'check_interval')
LOG_LEVEL=$(bashio::config 'log_level')

bashio::log.blue "================================================"
bashio::log.blue " MariaDB Arbiter (keepalived health)"
bashio::log.blue "================================================"
bashio::log.cyan "MariaDB primary:  ${MARIADB_PRIMARY}:${MARIADB_PORT}"
bashio::log.cyan "MariaDB standby:  ${MARIADB_STANDBY}:${MARIADB_PORT}"
bashio::log.cyan "Health endpoint:  :${HEALTH_PORT}"
bashio::log.cyan "Check interval:   ${CHECK_INTERVAL}s"
bashio::log.cyan "Log level:        ${LOG_LEVEL}"
bashio::log.blue "================================================"

check_mariadb() {
    local host="$1"
    if nc -z -w2 "${host}" "${MARIADB_PORT}" 2>/dev/null; then
        local readonly_status
        readonly_status=$(mariadb -h "${host}" -P "${MARIADB_PORT}" -u healthcheck --skip-password \
            -e "SELECT @@global.read_only;" -sN 2>/dev/null || echo "1")
        if [ "${readonly_status}" = "0" ]; then
            echo "rw"
        else
            echo "ro"
        fi
    else
        echo "down"
    fi
}

bashio::log.green "Starting MariaDB arbiter on port ${HEALTH_PORT}..."

# Main loop — serve HTTP health responses
while true; do
    primary_status=$(check_mariadb "${MARIADB_PRIMARY}")
    standby_status=$(check_mariadb "${MARIADB_STANDBY}")

    if [ "${primary_status}" = "rw" ]; then
        current_primary="${MARIADB_PRIMARY}"
    elif [ "${standby_status}" = "rw" ]; then
        current_primary="${MARIADB_STANDBY}"
    elif [ "${standby_status}" = "ro" ]; then
        current_primary="PROMOTE_STANDBY"
    else
        current_primary="NONE"
    fi

    RESPONSE="{\"primary\":\"${current_primary}\",\"primary_status\":\"${primary_status}\",\"standby_status\":\"${standby_status}\"}"
    HEADERS="HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: ${#RESPONSE}\r\nConnection: close\r\n\r\n"

    echo -ne "${HEADERS}${RESPONSE}" | nc -l -p "${HEALTH_PORT}" -q 1 2>/dev/null || true
done
