#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
set -euo pipefail

# Read configuration from add-on options
SSH_PORT=$(bashio::config 'ssh_port')
QNETD_PORT=$(bashio::config 'qnetd_port')
LOG_LEVEL=$(bashio::config 'log_level')

bashio::log.blue "================================================"
bashio::log.blue " Proxmox QDevice (corosync-qnetd)"
bashio::log.blue "================================================"
bashio::log.cyan "SSH port:   ${SSH_PORT}"
bashio::log.cyan "QNetd port: ${QNETD_PORT}"
bashio::log.cyan "Log level:  ${LOG_LEVEL}"
bashio::log.blue "================================================"

# --- SSH Key Authentication Setup ---
mkdir -p /root/.ssh
chmod 700 /root/.ssh
: > /root/.ssh/authorized_keys

KEY_COUNT=$(bashio::config 'authorized_keys | length')
for (( i=0; i < KEY_COUNT; i++ )); do
    key=$(bashio::config "authorized_keys[${i}]")
    if [ -n "${key}" ]; then
        echo "${key}" >> /root/.ssh/authorized_keys
    fi
done
chmod 600 /root/.ssh/authorized_keys

if [ "${KEY_COUNT}" -eq 0 ]; then
    bashio::log.fatal "No SSH authorized keys configured!"
    bashio::log.fatal "Add your Proxmox node's public key to the authorized_keys list."
    bashio::log.fatal "Run on each Proxmox node: cat /root/.ssh/id_rsa.pub"
    exit 1
fi

bashio::log.info "SSH key authentication: ${KEY_COUNT} key(s) loaded"

# Generate SSH host keys if they don't exist (persist across restarts)
mkdir -p /data/qnetd
if [ ! -f /data/qnetd/ssh_host_rsa_key ]; then
    bashio::log.info "Generating SSH host keys (first run)..."
    ssh-keygen -t rsa -b 4096 -f /data/qnetd/ssh_host_rsa_key -N "" -q
    ssh-keygen -t ed25519 -f /data/qnetd/ssh_host_ed25519_key -N "" -q
fi

# Configure SSHD — key auth only, no passwords
cat > /etc/ssh/sshd_config << EOF
Port ${SSH_PORT}
HostKey /data/qnetd/ssh_host_rsa_key
HostKey /data/qnetd/ssh_host_ed25519_key
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
AuthorizedKeysFile /root/.ssh/authorized_keys
Subsystem sftp /usr/lib/openssh/sftp-server
PrintMotd no
AcceptEnv LANG LC_*
EOF

# Create qnetd certificate database directory
NSSDB="/etc/corosync/qnetd/nssdb"
mkdir -p "$(dirname "${NSSDB}")"

# Initialise qnetd certificate database if not already done
if [ ! -f "${NSSDB}/cert9.db" ] && [ ! -f "${NSSDB}/cert8.db" ]; then
    bashio::log.info "Initialising QNetd certificate database..."
    corosync-qnetd-certutil -i
fi

# Determine qnetd log level
QNETD_LOG_LEVEL="4"
case "${LOG_LEVEL}" in
    DEBUG)   QNETD_LOG_LEVEL="10" ;;
    INFO)    QNETD_LOG_LEVEL="4"  ;;
    WARNING) QNETD_LOG_LEVEL="2"  ;;
    ERROR)   QNETD_LOG_LEVEL="1"  ;;
esac

# Start SSHD in the background
bashio::log.green "Starting SSH daemon on port ${SSH_PORT}..."
/usr/sbin/sshd -e

# Start corosync-qnetd in the foreground
bashio::log.info "Starting corosync-qnetd on port ${QNETD_PORT}..."
exec corosync-qnetd -f -p "${QNETD_PORT}" -d "${QNETD_LOG_LEVEL}"

