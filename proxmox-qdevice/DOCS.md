# Proxmox QDevice — Documentation

## Overview

This add-on runs `corosync-qnetd` — the Corosync Qorum Network Daemon — which provides an external quorum vote for Proxmox VE clusters. It enables automatic HA failover in 2-node clusters by supplying the third vote needed for a node to achieve quorum after its peer fails.

## Prerequisites

- A 2-node Proxmox VE cluster (PVE 7.x or 8.x)
- Home Assistant running on hardware **separate** from the Proxmox cluster
- Network connectivity between Proxmox nodes and the Home Assistant host

## Configuration Options

### `authorized_keys` (required)

A list of SSH public keys from your Proxmox nodes. These are the keys that `pvecm qdevice setup` uses to connect during the initial certificate exchange.

To retrieve the key from a Proxmox node:

```bash
cat /root/.ssh/id_rsa.pub
```

If no key exists, generate one:

```bash
ssh-keygen -t rsa -b 4096 -N ""
```

**All nodes in your Proxmox cluster must have their public key listed here.** The setup command can be run from any node, and all nodes participate in the certificate exchange.

### `ssh_port` (default: 2222)

The TCP port for the SSH daemon. Proxmox connects to this during `pvecm qdevice setup` to exchange TLS certificates. Using a non-standard port avoids conflict with the Home Assistant SSH add-on (port 22).

### `qnetd_port` (default: 5403)

The TCP port for the corosync-qnetd service. After initial setup, Proxmox nodes maintain a persistent connection to this port for quorum voting. This is the standard corosync-qnetd port.

### `log_level` (default: INFO)

Controls the verbosity of corosync-qnetd logging. Available levels:

- **DEBUG** — Very verbose, includes internal state changes
- **INFO** — Normal operation, connection/disconnection events
- **WARNING** — Unusual conditions that don't prevent operation
- **ERROR** — Failures only

## Initial Setup

### Step 1: Retrieve SSH public keys from Proxmox nodes

On **each** Proxmox node in your cluster, run:

```bash
cat /root/.ssh/id_rsa.pub
```

If the file doesn't exist, generate a key pair first:

```bash
ssh-keygen -t rsa -b 4096 -N ""
cat /root/.ssh/id_rsa.pub
```

Copy the full output (starts with `ssh-rsa` and ends with `root@hostname`).

### Step 2: Configure and start the add-on

In the Home Assistant UI, paste each node's public key into the `authorized_keys` list:

```yaml
authorized_keys:
  - "ssh-rsa AAAAB3NzaC1yc2EAAA... root@proxmox-node1"
  - "ssh-rsa AAAAB3NzaC1yc2EAAA... root@proxmox-node2"
```

Start the add-on. Check the logs to confirm SSH and QNetd started successfully.

### Step 3: Configure SSH on each Proxmox node

`pvecm qdevice setup` uses SSH port 22 by default and does not support a custom port flag. Since this add-on listens on port 2222 (to avoid conflicting with the HA SSH add-on), you need to add an SSH client config entry on **each** Proxmox node:

```bash
# Run on EACH Proxmox node:
cat >> /root/.ssh/config << 'EOF'

Host <HA_IP>
    Port 2222
EOF
```

Replace `<HA_IP>` with your Home Assistant's IP address (e.g. `10.0.0.84`).

### Step 4: Run the setup command

On **one** Proxmox node (it doesn't matter which):

```bash
pvecm qdevice setup <HA_IP> -f
```

The `-f` flag forces setup even if a previous QDevice was configured. No password prompt — SSH key authentication handles the handshake automatically.

### Step 5: Verify

```bash
# On any Proxmox node:
pvecm qdevice status
pvecm status
```

Expected output shows the QDevice connected and providing 1 vote.

## Troubleshooting

### "Cannot connect to qnetd host"

- Verify the add-on is running (check HA logs)
- Confirm network connectivity: `nc -zv <HA_IP> 2222` (SSH) and `nc -zv <HA_IP> 5403` (QNetd)
- Check firewall rules allow both ports from Proxmox nodes

### "Connection refused" on SSH

- Ensure no other add-on is using port 2222 (e.g. old QDevice add-on)
- If QNetd fails to start (port 5403 in use), sshd also won't be reachable — check add-on logs for "address in use" errors
- Stop any conflicting add-ons, then restart this one

### "scp: Connection closed" during setup

- This means SSH connects but the SFTP subsystem fails
- Usually a path issue in sshd_config — update the add-on to the latest version
- Workaround: `ssh root@<HA_IP> 'ln -sf /usr/lib/openssh/sftp-server /usr/lib/ssh/sftp-server'`

### "NSS error: Local Network address is in use"

- Port 5403 is already bound by another process (usually an old QDevice add-on)
- Stop the conflicting add-on/service, then restart this one

### SSH config not taking effect / wrong port

- `pvecm` does not support a `--port` flag — it always uses the SSH client config
- Ensure `/root/.ssh/config` on each Proxmox node has the correct entry:
  ```
  Host <HA_IP>
      Port 2222
  ```
- If you previously used a different QDevice add-on, check for duplicate/conflicting `Host` entries — SSH uses the **first match**

### "Certificate error during setup"

- If re-running setup after a rebuild, use the `-f` flag to force certificate re-exchange
- On the Proxmox side: `pvecm qdevice remove` then re-run setup

### "QDevice not connected" after reboot

- The add-on starts automatically with `boot: auto`
- Check that Home Assistant boots before the Proxmox nodes attempt reconnection
- Proxmox will retry the connection periodically (every 10s by default)

### Checking quorum in real-time

```bash
# Live quorum status
corosync-quorumtool -s

# QDevice connection state
corosync-qdevice-tool -s

# Full cluster status with QDevice votes
pvecm status
```

## Data Persistence

The add-on stores the following in `/data/qnetd/`:

- SSH host keys (persist across add-on rebuilds, avoiding SSH fingerprint changes)
- QNetd certificate database (in `/etc/corosync/qnetd/nssdb/`)

If you completely remove and reinstall the add-on, you'll need to re-run `pvecm qdevice setup` on the Proxmox cluster.

## Security Considerations

- **No passwords** — SSH key authentication only, password auth is disabled
- SSH is used **only** for the initial certificate exchange, not for runtime operation
- After setup, the persistent connection uses TLS certificates exchanged during setup
- SSH host keys are persisted in /data/ (survive add-on rebuilds, stable fingerprints)
- `PermitRootLogin prohibit-password` — root can only log in with a listed key
- Consider restricting SSH access via firewall rules to your Proxmox node IPs only

## Network Diagram

```
Proxmox Node A ──────┐
  (corosync ring)     ├──── TCP 5403 ────► HA (corosync-qnetd)
Proxmox Node B ──────┘
                           TCP 2222 ────► HA (sshd, setup only)
```

## Compatibility

| Proxmox VE | Status |
|------------|--------|
| 8.x | ✅ Tested |
| 7.x | ✅ Should work (same corosync-qnetd protocol) |
| 6.x | ⚠️ Untested |
