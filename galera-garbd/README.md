# Galera Arbitrator (garbd) — Home Assistant Add-on

[![Open your Home Assistant instance and show the add-on store with a specific repository URL pre-filled.][ha-store-badge]][ha-store-link]

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

A lightweight Home Assistant add-on that provides a **Galera Cluster quorum vote**
for a 2-node MariaDB Galera cluster using the official
[garbd](https://mariadb.com/kb/en/galera-cluster-garbd/) arbitrator daemon.

[ha-store-badge]: https://my.home-assistant.io/badges/supervisor_store.svg
[ha-store-link]: https://my.home-assistant.io/redirect/supervisor_store/?repository_url=https%3A%2F%2Fgithub.com%2Fsuper12v%2Fhassio-addons
[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg

## Why

A Galera cluster requires an odd number of voters to maintain quorum and prevent
split-brain. With 2 MariaDB data nodes, if one node fails the surviving node
cannot determine whether it should continue operating or whether it's the one
that's been partitioned off.

This add-on runs `garbd` (Galera Arbitrator Daemon) — a stateless process that
participates in Galera group communication for voting purposes only. It stores
no data and uses negligible resources.

## Architecture

```
┌────────────────────┐     ┌────────────────────┐     ┌────────────────────┐
│  MariaDB Node 1    │     │  MariaDB Node 2    │     │  HA RPi (garbd)    │
│  Galera + Data     │◄───►│  Galera + Data     │◄───►│  Home Assistant    │
│  Read/Write        │     │  Read/Write        │     │  Vote only         │
│  :3306 :4567       │     │  :3306 :4567       │     │  :4567             │
└────────────────────┘     └────────────────────┘     └────────────────────┘
         │                          │                          │
         └──────────────────────────┴──────────────────────────┘
                       Galera group communication (3 voters)
                       Quorum = 2/3 for cluster Primary status
```

## How It Works

1. garbd joins the Galera group communication channel on port 4567
2. It receives and acknowledges all write-set certification events
3. It votes in quorum decisions but never applies or stores data
4. If a data node dies, garbd + surviving node = 2/3 majority = cluster stays Primary

**Multi-master:** Both data nodes accept reads AND writes simultaneously.
There is no primary/standby distinction — Galera is synchronous multi-master.

## Failover Scenarios

| Scenario | Quorum | Result |
|----------|--------|--------|
| Node 1 dies | Node 2 + garbd = 2/3 ✅ | Cluster continues, all traffic to Node 2 |
| Node 2 dies | Node 1 + garbd = 2/3 ✅ | Cluster continues, all traffic to Node 1 |
| garbd (RPi) dies | Node 1 + Node 2 = 2/3 ✅ | Cluster continues (both data nodes up) |
| Node 1 + garbd die | Node 2 alone = 1/3 ❌ | Node 2 goes non-Primary (read-only) |
| Network partition | Side with 2/3 wins | Minority side goes non-Primary |

## Installation

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**
2. Click **⋮** (top right) → **Repositories**
3. Add: `https://github.com/super12v/hassio-addons`
4. Find "Galera Arbitrator (garbd)" in the store and install
5. Configure the add-on (see below)
6. Start the add-on

## Configuration

```yaml
cluster_name: "my-galera-cluster"          # Must match wsrep_cluster_name on MariaDB nodes
cluster_address: "gcomm://192.168.1.10,192.168.1.11"  # Both MariaDB node IPs
log_level: "INFO"                          # DEBUG, INFO, WARNING, ERROR
```

| Option | Default | Description |
|--------|---------|-------------|
| `cluster_name` | `my-galera-cluster` | Galera cluster name — must match `wsrep_cluster_name` on both data nodes |
| `cluster_address` | `gcomm://192.168.1.10,192.168.1.11` | Comma-separated IPs of both MariaDB Galera nodes |
| `log_level` | `INFO` | Logging verbosity |

**Important:** The `cluster_name` must match exactly what's configured in
`wsrep_cluster_name` on both MariaDB nodes.

## Requirements

- Home Assistant OS on Raspberry Pi 4 (aarch64)
- Network connectivity to both MariaDB nodes on port 4567 (TCP and UDP)
- Both MariaDB nodes must include this RPi's IP in their `wsrep_cluster_address`
- MariaDB nodes must be running Galera 4.x (MariaDB 10.4+)

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 4567 | TCP + UDP | Galera group communication |

## Resource Usage

| Resource | Usage |
|----------|-------|
| RAM | ~20 MB |
| CPU | Negligible (<1%) |
| Disk | None (stateless) |
| Network | ~1-5 KB/s (certification events) |

## Monitoring

Verify the cluster sees 3 members from any MariaDB node:

```sql
SHOW STATUS LIKE 'wsrep_cluster_size';
-- Expected: 3

SHOW STATUS LIKE 'wsrep_incoming_addresses';
-- Should list both data node IPs
```

## Troubleshooting

### garbd won't connect
- Verify port 4567 is reachable from the RPi to both MariaDB nodes
- Check `cluster_name` matches `wsrep_cluster_name` exactly (case-sensitive)
- Ensure the MariaDB Galera cluster is running (at least one node bootstrapped)
- Check add-on logs for connection errors

### wsrep_cluster_size stays at 2
- garbd may not be running — check add-on status in HA
- Network/firewall blocking port 4567 between RPi and MariaDB nodes
- If nodes are on a different subnet, ensure routing is configured

### Cluster goes non-Primary after garbd restart
- This is normal briefly during garbd reconnection
- The cluster should return to Primary within a few seconds
- If it doesn't, check if both data nodes are actually running

## License

MIT
