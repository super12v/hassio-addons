# Redis Sentinel — Home Assistant Add-on

Redis Sentinel tiebreaker vote for automatic Redis HA failover.

## What This Does

Runs a Redis Sentinel instance that monitors your Redis primary/replica pair and casts the deciding vote when failover is needed. Combined with the Sentinels running on each Redis CT, this gives you a 3-node quorum for split-brain-safe automatic failover.

## Architecture

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│ redis-primary    │     │ redis-standby    │     │ HA RPi           │
│ Redis + Sentinel │◄───►│ Redis + Sentinel │◄───►│ Sentinel (voter) │
│ (node 1)         │     │ (node 2)         │     │ (this add-on)    │
└──────────────────┘     └──────────────────┘     └──────────────────┘
                    Sentinel quorum: 2/3
```

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `redis_primary_host` | — | Redis primary IP |
| `redis_primary_port` | `6379` | Redis port |
| `sentinel_port` | `26379` | Sentinel listen port |
| `quorum` | `2` | Votes needed to declare primary down |
| `down_after_ms` | `5000` | ms before marking node down |
| `failover_timeout` | `30000` | Max failover duration (ms) |
| `log_level` | `INFO` | Logging verbosity |

## License

MIT
