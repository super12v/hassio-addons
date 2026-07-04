# Galera Arbitrator (garbd)

Galera Cluster arbitrator daemon for Home Assistant OS. Provides quorum voting for a 2-node MariaDB Galera cluster without storing any data.

## Purpose

A Galera cluster needs an odd number of voters to avoid split-brain. With 2 data nodes, this add-on provides the 3rd vote from a separate host. If one data node dies, the survivor + garbd = 2/3 majority = cluster continues operating.

## Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `cluster_name` | Galera cluster name (must match `wsrep_cluster_name`) | `my-galera-cluster` |
| `cluster_address` | `gcomm://` address of data nodes | `gcomm://192.168.1.10,192.168.1.11` |
| `log_level` | Logging verbosity | `INFO` |

## Network

- **Port 4567 (TCP+UDP):** Galera group communication. Must be reachable from both MariaDB nodes.
- Ensure routing exists between this host and the MariaDB nodes if they are on different subnets.

## Resource Usage

- RAM: ~20 MB
- CPU: negligible
- Disk: none (no data stored)
