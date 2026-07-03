# Patroni Raft Voter — Home Assistant Add-on

[![Open your Home Assistant instance and show the add-on store with a specific repository URL pre-filled.][ha-store-badge]][ha-store-link]

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

A lightweight Home Assistant add-on that provides a **Raft tiebreaker vote** for a
[Patroni](https://patroni.readthedocs.io/) PostgreSQL HA cluster.

[ha-store-badge]: https://my.home-assistant.io/badges/supervisor_store.svg
[ha-store-link]: https://my.home-assistant.io/redirect/supervisor_store/?repository_url=https%3A%2F%2Fgithub.com%2Fsuper12v%2Fhassio-addon-patroni-raft
[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg

## What This Does

Patroni's built-in Raft consensus requires an odd number of voters (3, 5, etc.) to
maintain quorum and prevent split-brain. With a 2-node database cluster (primary +
standby), a third voter is needed to break ties during failover decisions.

This add-on runs a **Patroni Raft voter only** — no PostgreSQL is installed. It
participates in the Raft consensus protocol, providing the quorum needed for
automatic failover when the primary database node fails.

## Architecture

```
┌────────────────────┐     ┌────────────────────┐     ┌────────────────────┐
│  db-primary        │     │  db-standby        │     │  HA RPi (voter)    │
│  Patroni + PG      │◄───►│  Patroni + PG      │◄───►│  Patroni + PG*     │
│  Node 1            │     │  Node 2            │     │  Home Assistant    │
│  :5010 (Raft)      │     │  :5010 (Raft)      │     │  :5010 (Raft)      │
└────────────────────┘     └────────────────────┘     └────────────────────┘
         │                          │                          │
         └──────────────────────────┴──────────────────────────┘
                          Raft consensus (3 voters)
                          Majority = 2/3 for promotion
```

*\*The RPi runs a real but idle PostgreSQL instance (required by Patroni) that
is bound to localhost only and never participates in replication or failover.*

**Quorum:** 2 of 3 voters must agree for leadership changes.

## How It Works

Patroni requires all cluster members to run PostgreSQL — there is no pure
"voter-only" mode. This add-on works around that by running a minimal PG
instance with the following constraints:

- `nofailover: true` — can never be elected primary
- `nosync: true` — never becomes a synchronous standby
- `noloadbalance: true` — never receives client queries
- `listen_addresses: 127.0.0.1` — no external network access to PG
- `max_connections: 5` — minimal resource usage

The PG instance uses ~10MB RAM when idle. Its sole purpose is satisfying
Patroni's requirement so the node can participate in Raft consensus voting.

## Failover Scenarios

| Scenario | Quorum | Result |
|----------|--------|--------|
| Primary dies | Standby + RPi = 2/3 ✅ | Automatic promotion |
| Standby dies | Primary + RPi = 2/3 ✅ | Primary stays, degraded |
| RPi dies | Primary + Standby = 2/2 | No quorum for new elections (existing leader stays) |
| Network partition (primary isolated) | Standby + RPi = 2/3 ✅ | Standby promoted |

## Installation

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**
2. Click **⋮** (top right) → **Repositories**
3. Add: `https://github.com/super12v/hassio-addon-patroni-raft`
4. Find "Patroni Raft Voter" in the store and install
5. Configure the add-on (see below)
6. Start the add-on

## Configuration

```yaml
self_addr: "192.168.1.100:5010"      # This RPi's IP and Raft port
partner_addrs:                    # The other Patroni nodes
  - "192.168.1.10:5010"             # db-primary (node-1)
  - "192.168.1.11:5010"             # db-standby (node-2)
scope: "my-db-cluster"              # Patroni cluster name (must match)
namespace: "/db/"                # Patroni namespace (must match)
log_level: "INFO"                # DEBUG, INFO, WARNING, ERROR
```

**Important:** The `scope` and `namespace` must match exactly what's configured
on the primary and standby Patroni nodes.

## Requirements

- Home Assistant OS on Raspberry Pi 4 (aarch64)
- Network connectivity to both database nodes (ports 5010 and 8008)
- The database nodes must be configured with this RPi's address in their
  `raft.partner_addrs` list

## Resource Usage

| Resource | Usage |
|----------|-------|
| RAM | ~50 MB |
| CPU | Negligible (<1%) |
| Disk | <10 MB (Raft state) |
| Network | ~1 KB/s (heartbeats) |

## Monitoring

The add-on exposes a Patroni REST API on port 8008:

```bash
# Check Raft cluster status
curl http://192.168.1.100:8008/patroni

# Check cluster topology (from any Patroni node)
patronictl -c /etc/patroni.yml list
```

## Troubleshooting

### Add-on won't start
- Check that ports 5010 and 8008 are not in use
- Verify network connectivity to partner nodes: `ping 192.168.1.10`

### Raft not forming quorum
- All three nodes must be running and reachable on port 5010
- Check `scope` and `namespace` match across all nodes
- Check add-on logs for connection errors

### Split-brain concerns
- This add-on prevents split-brain by providing quorum
- With synchronous replication on the DB nodes, writes block if standby unreachable
- No data can diverge — the system prefers unavailability over inconsistency

## License

MIT
