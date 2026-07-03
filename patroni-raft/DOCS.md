# Patroni Raft Voter

A lightweight tiebreaker for Patroni PostgreSQL HA clusters. This add-on provides a third Raft vote enabling automatic failover when a database node fails.

## How it works

Patroni uses built-in Raft consensus to elect a leader for the PostgreSQL cluster. With only 2 database nodes, a failure leaves no majority for promotion. This add-on runs a Raft-only voter (no database) giving the cluster the quorum it needs.

## Configuration

### Option: `self_addr`

The IP address and port of this Home Assistant instance for Raft communication. Use the IP that your database nodes can reach.

### Option: `partner_addrs`

List of Patroni node addresses (IP:port) that participate in the Raft cluster. These are your database primary and standby nodes.

### Option: `scope`

The Patroni cluster name. Must match exactly what is configured on your database nodes in their `patroni.yml`.

### Option: `namespace`

The Patroni namespace. Must match your database nodes. Default is `/db/`.

### Option: `replication_username`

PostgreSQL replication username. Must match the `authentication.replication.username` value in your primary and standby Patroni configuration (`patroni.yml`).

### Option: `replication_password`

PostgreSQL replication password. Must match the `authentication.replication.password` value in your Patroni nodes.

**Where to find it:** Check your primary Patroni config:
```bash
grep -A2 "replication:" /etc/patroni/patroni.yml
```

### Option: `superuser_username`

PostgreSQL superuser name. Must match `authentication.superuser.username` on your Patroni nodes. Typically `postgres`.

### Option: `superuser_password`

PostgreSQL superuser password. Must match `authentication.superuser.password` on your Patroni nodes.

**Where to find it:** Check your primary Patroni config:
```bash
grep -A2 "superuser:" /etc/patroni/patroni.yml
```

### Setting up credentials from scratch

If you're building a new Patroni cluster, choose strong passwords and set them consistently across all nodes (primary, standby, and this tiebreaker):

```yaml
# In patroni.yml on each node:
postgresql:
  authentication:
    replication:
      username: replicator
      password: your-replication-password
    superuser:
      username: postgres
      password: your-superuser-password
```

Then enter the same values in this add-on's configuration. All three nodes **must** use identical credentials.

### Option: `log_level`

Logging verbosity. Use `INFO` for normal operation, `DEBUG` for troubleshooting.

### Option: `pg_version`

The PostgreSQL major version running on your primary and standby nodes. This add-on must use the same version for replication compatibility.

**How to check your primary's version:**
```bash
postgres --version
# or
patronictl -c /etc/patroni/patroni.yml list
```

Supported values: `14`, `15`, `16`, `17`

If you change this value (e.g., after upgrading your primary), the add-on will automatically wipe its local data directory and re-bootstrap from the leader on next start.

## Network

This add-on uses host networking to communicate directly with Patroni nodes on port 5010 (Raft) and exposes a REST API on port 8008.

Ensure your firewall allows:
- Port 5010 (Raft consensus) between all three nodes
- Port 8008 (Patroni REST API) for monitoring

## Implementation Detail

Patroni requires all cluster members to run PostgreSQL — there is no pure
"voter-only" mode. This add-on includes a real PostgreSQL instance that runs
with the following constraints to ensure it only votes and never handles data:

- **nofailover: true** — can never be elected primary
- **nosync: true** — never becomes a synchronous standby
- **noloadbalance: true** — never receives client queries
- **listen_addresses: 127.0.0.1** — PG only accessible from inside the container
- **max_connections: 5** — minimal resource usage (~10MB RAM idle)

This is a necessary workaround for Patroni's architecture. The PG instance
on the RPi holds no data and serves no queries — it exists solely to satisfy
Patroni's internal requirements for cluster membership.

## Resource Usage

| Resource | Usage |
|----------|-------|
| RAM | ~60 MB (Patroni + idle PG) |
| CPU | Negligible (<1%) |
| Disk | ~50 MB (PG data dir, mostly empty) |
| Network | ~1 KB/s (Raft heartbeats) |

## Support

Report issues at: <https://github.com/super12v/hassio-addon-patroni-raft/issues>
