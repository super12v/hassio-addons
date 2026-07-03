# Database Quorum — Home Assistant Add-on

Redis Sentinel + MariaDB keepalived arbitrator, providing tiebreaker votes for database HA failover.

## What This Does

This add-on runs on an independent host (e.g. Raspberry Pi) and provides:

1. **Redis Sentinel** — monitors your Redis primary/replica pair and casts the deciding vote on automatic failover
2. **MariaDB Arbiter** — HTTP health endpoint that keepalived on the MariaDB CTs queries to determine which node should hold the VIP

Together with the Sentinel instances running on each Redis CT, this gives you a 3-node Sentinel quorum for split-brain-safe Redis failover.

## Architecture

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│ redis-primary    │     │ redis-standby    │     │ HA RPi           │
│ Redis + Sentinel │◄───►│ Redis + Sentinel │◄───►│ Sentinel (voter) │
│ CT 145 (picard)  │     │ CT 146 (riker)   │     │ (this add-on)    │
└──────────────────┘     └──────────────────┘     └──────────────────┘
         Sentinel quorum: 2/3

┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│ mariadb-primary  │     │ mariadb-standby  │     │ HA RPi           │
│ MariaDB + keepa  │     │ MariaDB + keepa  │     │ Arbiter (HTTP)   │
│ CT 143 (picard)  │     │ CT 144 (riker)   │     │ (this add-on)    │
└──────────────────┘     └──────────────────┘     └──────────────────┘
         Keepalived VIP: 10.0.1.53
```

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `redis_primary_host` | — | Redis primary IP |
| `redis_primary_port` | `6379` | Redis port |
| `redis_sentinel_port` | `26379` | Sentinel listen port |
| `redis_quorum` | `2` | Votes needed to declare primary down |
| `redis_down_after_ms` | `5000` | ms before marking node down |
| `redis_failover_timeout` | `30000` | Max failover duration (ms) |
| `mariadb_primary_host` | — | MariaDB primary IP |
| `mariadb_standby_host` | — | MariaDB standby IP |
| `mariadb_port` | `3306` | MariaDB port |
| `mariadb_health_port` | `8306` | Arbiter HTTP endpoint port |
| `log_level` | `INFO` | Logging verbosity |

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 26379 | TCP | Redis Sentinel |
| 8306 | TCP | MariaDB arbiter health endpoint |

## License

MIT
