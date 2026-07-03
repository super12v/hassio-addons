# MariaDB Arbiter — Home Assistant Add-on

Keepalived health arbitrator for MariaDB HA failover.

## What This Does

Runs an HTTP health endpoint on an independent host (e.g. Raspberry Pi). Both MariaDB CTs run keepalived, which queries this arbiter to determine which node should hold the VIP. The arbiter checks which MariaDB is alive and read-write, providing a tiebreaker decision.

## Architecture

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│ mariadb-primary  │     │ mariadb-standby  │     │ HA RPi           │
│ MariaDB + keepa  │     │ MariaDB + keepa  │     │ Arbiter (HTTP)   │
│ (picard)         │     │ (riker)          │     │ (this add-on)    │
└────────┬─────────┘     └────────┬─────────┘     └────────┬─────────┘
         │                        │                         │
         └────── GET :8306/primary ─────────────────────────┘
                      VIP: 192.168.1.53
```

Keepalived check script on each MariaDB CT:
1. Queries arbiter: `GET http://<HA_IP>:8306/`
2. If response says this node is primary → keep VIP
3. If response says other node is primary → release VIP

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `mariadb_primary_host` | — | MariaDB primary IP |
| `mariadb_standby_host` | — | MariaDB standby IP |
| `mariadb_port` | `3306` | MariaDB port |
| `health_port` | `8306` | Arbiter HTTP endpoint port |
| `check_interval` | `2` | Health check frequency (seconds) |
| `log_level` | `INFO` | Logging verbosity |

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 8306 | TCP | HTTP health endpoint |

## License

MIT
