# Proxmox QDevice — Home Assistant Add-on

[![Open your Home Assistant instance and show the add-on store with a specific repository URL pre-filled.][ha-store-badge]][ha-store-link]

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

[ha-store-badge]: https://my.home-assistant.io/badges/supervisor_store.svg
[ha-store-link]: https://my.home-assistant.io/redirect/supervisor_store/?repository_url=https%3A%2F%2Fgithub.com%2Fsuper12v%2Fhassio-addon-proxmox-qdevice
[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg

Corosync QNetd service providing a third quorum vote for 2-node Proxmox VE clusters. Runs on Home Assistant (typically a Raspberry Pi) to enable automatic HA failover when a Proxmox node goes down.

## Why

A 2-node Proxmox cluster has an even number of votes. If one node fails, the surviving node cannot achieve quorum and won't start HA workloads. A QDevice provides the tiebreaker vote — the first node to reach the QDevice gets quorum and can fence the failed node.

**Important:** This add-on must run on hardware independent of your Proxmox cluster. Do not run it on a VM hosted by the cluster it's providing quorum for.

## Install

1. Add this repository to Home Assistant:
   - Navigate to **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
   - Add: `https://github.com/super12v/hassio-addon-proxmox-qdevice`
2. Install **Proxmox QDevice** from the store
3. Configure the options (see below)
4. Start the add-on

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `authorized_keys` | *(required)* | Public SSH keys from your Proxmox nodes |
| `ssh_port` | `2222` | SSH port for `pvecm qdevice setup` |
| `qnetd_port` | `5403` | Corosync QNetd listening port |
| `log_level` | `INFO` | Logging verbosity (DEBUG/INFO/WARNING/ERROR) |

## Setup

### Step 1: Get the SSH public key from each Proxmox node

```bash
# Run on EACH Proxmox node:
cat /root/.ssh/id_rsa.pub
```

If the key doesn't exist, generate it first:

```bash
ssh-keygen -t rsa -b 4096 -N ""
cat /root/.ssh/id_rsa.pub
```

### Step 2: Configure the add-on

Paste the public key(s) into the add-on configuration in Home Assistant:

```yaml
authorized_keys:
  - "ssh-rsa AAAAB3NzaC1yc2EAAA... root@node1"
  - "ssh-rsa AAAAB3NzaC1yc2EAAA... root@node2"
ssh_port: 2222
qnetd_port: 5403
log_level: INFO
```

Every node in the cluster needs its key listed. Start the add-on.

### Step 3: Run the setup command

On **one** Proxmox node (either one):

```bash
pvecm qdevice setup <HA_IP> -f --port <ssh_port>
```

Where `<HA_IP>` is your Home Assistant's IP address and `<ssh_port>` is the configured SSH port (default 2222).

No password prompt — key auth handles it.

### Step 4: Verify

```bash
# Check qdevice status
pvecm qdevice status

# Check quorum votes
pvecm status
```

You should see 3 votes: one per Proxmox node plus one from the QDevice.

## How It Works

```
┌─────────────────┐         ┌─────────────────┐
│  Proxmox Node 1 │◄──────►│  Proxmox Node 2 │
│   (1 vote)      │  ring   │   (1 vote)      │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │    ┌───────────────┐      │
         └───►│ Home Assistant │◄─────┘
              │   QDevice     │
              │   (1 vote)    │
              └───────────────┘
              Quorum: 2/3 votes
```

1. **Setup phase:** `pvecm qdevice setup` connects via SSH to exchange certificates
2. **Runtime:** Proxmox nodes connect to corosync-qnetd on port 5403
3. **Failover:** If a node dies, the survivor + QDevice = 2/3 votes = quorum achieved

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 2222 | TCP | SSH (setup handshake only) |
| 5403 | TCP | Corosync QNetd (runtime quorum) |

## License

MIT
