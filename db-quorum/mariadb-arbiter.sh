#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# MariaDB keepalived arbiter — HTTP health endpoint
# Both MariaDB CTs query this to determine who should hold the VIP.
# Returns the IP of the node that should be primary.
set -euo pipefail

MARIADB_PRIMARY="$1"
MARIADB_STANDBY="$2"
MARIADB_PORT="$3"
HEALTH_PORT="$4"

check_mariadb() {
    local host="$1"
    # Check if MariaDB is alive and accepting connections
    if nc -z -w2 "${host}" "${MARIADB_PORT}" 2>/dev/null; then
        # Check if it's read-write (not read_only)
        local readonly_status
        readonly_status=$(mariadb -h "${host}" -P "${MARIADB_PORT}" -u healthcheck --skip-password \
            -e "SELECT @@global.read_only;" -sN 2>/dev/null || echo "1")
        if [ "${readonly_status}" = "0" ]; then
            echo "rw"
            return 0
        else
            echo "ro"
            return 0
        fi
    fi
    echo "down"
    return 1
}

# Simple HTTP server using bash + netcat
# Keepalived on MariaDB CTs queries: GET /primary
# Response: JSON with the current primary host
while true; do
    primary_status=$(check_mariadb "${MARIADB_PRIMARY}" 2>/dev/null || true)
    standby_status=$(check_mariadb "${MARIADB_STANDBY}" 2>/dev/null || true)

    if [ "${primary_status}" = "rw" ]; then
        current_primary="${MARIADB_PRIMARY}"
    elif [ "${standby_status}" = "rw" ]; then
        current_primary="${MARIADB_STANDBY}"
    elif [ "${standby_status}" = "ro" ]; then
        # Primary is down, standby is up but read-only — needs promotion
        current_primary="PROMOTE_STANDBY"
    else
        current_primary="NONE"
    fi

    # Serve HTTP response
    RESPONSE="{\"primary\":\"${current_primary}\",\"primary_status\":\"${primary_status}\",\"standby_status\":\"${standby_status}\"}"
    HEADERS="HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: ${#RESPONSE}\r\nConnection: close\r\n\r\n"

    echo -ne "${HEADERS}${RESPONSE}" | nc -l -p "${HEALTH_PORT}" -q 1 2>/dev/null || true

done
