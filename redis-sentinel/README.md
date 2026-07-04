# Redis Sentinel — Home Assistant Add-on

[![Open your Home Assistant instance and show the add-on store with a specific repository URL pre-filled.][ha-store-badge]][ha-store-link]

![Supports aarch64 Architecture][aarch64-shield]
![Supports amd64 Architecture][amd64-shield]

A lightweight Home Assistant add-on that provides a **Redis Sentinel tiebreaker vote**
for automatic Redis failover in a master/replica topology.

[ha-store-badge]: https://my.home-assistant.io/badges/supervisor_store.svg
[ha-store-link]: https://my.home-assistant.io/redirect/supervisor_store/?repository_url=https%3A%2F%2Fgithub.com%2Fsuper12v%2Fhassio-addons
[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg

## Why

Redis Sentinel requires an odd number of sentinels for reliable quorum. With
2 Redis nodes (master + replica), each running its own Sentinel, you have 2 voters.
If the master dies, the remaining Sentinel alone cannot reach quorum to promote the
replica. This add-on provides the 3rd vote from a separate host.

## Architecture

```
┌────────────────────┐     ┌────────────────────┐     ┌────────────────────┐
│  Redis Master      │     │  Redis Replica     │     │  HA RPi (Sentinel) │
│  + Sentinel        │◄───►│  + Sentinel        │◄───►│  Home Assistant    │
│  Node 1            │     │  Node 2            │     │  Vote only         │
│  :6379 :26379      │     │  :6379 :26379      │     │  :26379            │
└────────────────────┘     └────────────────────┘     └────────────────────┘
         │                          │                          │
         └──────────────────────────┴──────────────────────────┘
                       Sentinel consensus (3 voters)
                       Quorum = 2/3 for promotion
```

## How It Works

1. Sentinel connects to the Redis master and monitors it via PING
2. If the master doesn't respond for `down_after_ms`, Sentinel marks it as SDOWN
3. When `quorum` sentinels agree (2/3), the master is marked ODOWN (objectively down)
4. A leader sentinel is elected and promotes the best replica to master
5. All other replicas are reconfigured to follow the new master

## Failover Scenarios

| Scenario | Quorum | Result |
|----------|--------|--------|
| Master dies | Replica Sentinel + RPi Sentinel = 2/3 ✅ | Replica promoted to master |
| Replica dies | Master continues | No failover needed |
| RPi (this add-on) dies | Master Sentinel + Replica Sentinel = 2/3 ✅ | Failover still works |
| Master + RPi die | Replica Sentinel alone = 1/3 ❌ | Cannot reach quorum — no promotion |

## Installation

1. In Home Assistant, go to **Settings → Add-ons → Add-on Store**
2. Click **⋮** (top right) → **Repositories**
3. Add: `https://github.com/super12v/hassio-addons`
4. Find "Redis Sentinel" in the store and install
5. Configure the add-on (see below)
6. Start the add-on

## Configuration

```yaml
master_name: "my-redis"           # Sentinel group name (must match all sentinels)
master_host: "192.168.1.10"       # Current Redis master IP
master_port: 6379                 # Redis port
master_password: "your-password"  # Redis AUTH password (leave empty if none)
quorum: 2                         # Sentinels needed to agree on failover
down_after_ms: 5000               # 5 seconds before marking master down
failover_timeout: 10000           # 10 seconds max for failover operation
log_level: "INFO"
```

| Option | Default | Description |
|--------|---------|-------------|
| `master_name` | `my-redis` | Sentinel monitor group name — must be identical across all sentinels |
| `master_host` | `192.168.1.10` | IP of the current Redis master |
| `master_port` | `6379` | Redis listening port |
| `master_password` | *(empty)* | `requirepass` value on Redis nodes |
| `quorum` | `2` | Minimum sentinels to agree master is down |
| `down_after_ms` | `5000` | Milliseconds without PONG before SDOWN |
| `failover_timeout` | `10000` | Max failover duration (ms) |
| `log_level` | `INFO` | Verbosity |

## Requirements

- Home Assistant OS on Raspberry Pi 4 (aarch64)
- Network connectivity to Redis master and replica on ports 6379 and 26379
- The Redis nodes' sentinels must be able to reach this host on port 26379

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 26379 | TCP | Sentinel communication (inter-sentinel + client discovery) |

## Resource Usage

| Resource | Usage |
|----------|-------|
| RAM | ~10 MB |
| CPU | Negligible (<1%) |
| Disk | <1 MB |
| Network | ~1 KB/s (heartbeats) |

## Troubleshooting

### Sentinel can't find master
- Verify `master_host` IP is reachable from the RPi on port 6379
- If Redis has `requirepass`, ensure `master_password` is set correctly
- Check that `master_name` matches what the other sentinels are using

### Failover not happening
- Verify `quorum` sentinels can agree (check `sentinel master <name>` on each)
- Check `num-other-sentinels` — should be 2 (if 3 total sentinels)
- Ensure port 26379 is reachable between all sentinel hosts

### After failover, old master won't rejoin
- Redis should auto-rejoin as replica when restarted (Sentinel reconfigures it)
- If it comes back as master, Sentinel will demote it within `down_after_ms`

## License

MIT
