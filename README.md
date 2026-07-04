# super12v's Add-ons for Home Assistant

[![Open your Home Assistant instance and show the add-on store with a specific repository URL pre-filled.][ha-store-badge]][ha-store-link]

Home Assistant add-ons for homelab infrastructure — cluster quorum, database HA, and more.

## Add-ons

| Add-on | Description | Docs |
|--------|-------------|------|
| **[Patroni Raft Voter](patroni-raft/)** | Raft tiebreaker vote for Patroni PostgreSQL HA clusters | [README](patroni-raft/README.md) |
| **[Proxmox QDevice](proxmox-qdevice/)** | Corosync QNetd quorum vote for 2-node Proxmox VE clusters | [README](proxmox-qdevice/README.md) |
| **[Redis Sentinel](redis-sentinel/)** | Sentinel tiebreaker vote for Redis HA failover | [README](redis-sentinel/README.md) |
| **[Galera Arbitrator](galera-garbd/)** | Galera quorum voter (garbd) for MariaDB Galera Cluster HA | [README](galera-garbd/README.md) |

## Install

Add this repository to Home Assistant:

1. Navigate to **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
2. Add: `https://github.com/super12v/hassio-addons`
3. All add-ons will appear under **super12v's Add-ons**

## Architecture Support

All add-ons support:

![aarch64][aarch64-shield] ![amd64][amd64-shield]

Primary target: Raspberry Pi 4 running Home Assistant OS.

## License

MIT

[ha-store-badge]: https://my.home-assistant.io/badges/supervisor_store.svg
[ha-store-link]: https://my.home-assistant.io/redirect/supervisor_store/?repository_url=https%3A%2F%2Fgithub.com%2Fsuper12v%2Fhassio-addons
[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
[amd64-shield]: https://img.shields.io/badge/amd64-yes-green.svg
