# Changelog

## [1.2.0] — 2026-07-03

### Changed

- **Breaking:** Removed `root_password` option — SSH key auth only
- Password authentication is disabled in sshd_config
- `PermitRootLogin prohibit-password` enforced

### Added

- Documentation for retrieving Proxmox node public keys
- Clear error message if no keys configured

### Removed

- `root_password` configuration option

## [1.1.0] — 2026-07-03

### Added

- SSH authorized_keys option — key-based authentication for setup handshake
- Password and key auth can be used independently or together
- SSH auth method is logged on startup

### Changed

- root_password is now optional (was required)
- SSH only enables password/pubkey auth based on what's configured

## [1.0.1] — 2026-07-03

### Fixed

- Switched to Debian Bookworm base image (corosync-qnetd not available in Alpine)

## [1.0.0] — 2026-07-03

### Added

- Initial release
- Corosync QNetd daemon for Proxmox cluster quorum
- SSH daemon for `pvecm qdevice setup` handshake
- Configurable SSH and QNetd ports
- Persistent SSH host keys (survive add-on rebuilds)
- Multi-arch support (aarch64, amd64)
- GHCR-based image delivery
