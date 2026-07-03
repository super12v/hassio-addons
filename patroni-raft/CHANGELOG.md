# Changelog

## 1.1.0

- Switch to pre-built container images (GHCR)
- No more local builds — instant updates via image pull
- GitHub Actions CI builds multi-arch images on tag push
- Fix: run Patroni as postgres user (PG refuses root)
- Fix: chmod 700 on pgdata directory

## 1.0.7

- Add replication and superuser credentials as configuration options
- Credentials entered via HA UI (masked password fields)
- Never hardcoded in the repository

## 1.0.6

- Include real PostgreSQL 16 (Patroni requires it for all cluster members)
- PG runs idle, bound to localhost only, nofailover/nosync/noloadbalance
- Only participates in Raft consensus voting

## 1.0.5

- Add dummy postgresql section (Patroni parser requires it)

## 1.0.4

- Add psycopg2-binary dependency (required by Patroni even for voter-only)

## 1.0.3

- Add icon.png (128x128) and logo.png (256x256) — PostgreSQL elephant
- Version bump with matching git tag

## 1.0.2

- Add DOCS.md (shown in HA add-on info panel)
- Add translations/en.yaml (option labels in UI)
- Set init: false (required for s6-overlay v3)
- Set stage: experimental

## 1.0.1

- Fix run.sh for s6-overlay (bashio with-contenv)
- Replace real IPs with RFC examples in docs
- Remove node names from README

## 1.0.0

- Initial release
- Patroni 4.1.3 with built-in Raft consensus
- Configurable via Home Assistant add-on UI
- host_network mode for direct cluster communication
- Persistent Raft state in /data/raft
