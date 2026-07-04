# Patroni Raft Voter — Documentation

## Hardening Guide

This add-on supports optional security hardening. When enabled, the same settings
**must be applied to all 3 Patroni nodes** (both data nodes + this RPi) simultaneously.

### Overview

| Feature | What it protects | Impact if mismatched |
|---------|-----------------|---------------------|
| REST API auth | Prevents unauthorized failover/restart/reinit | `patronictl` and monitoring scripts break |
| Raft password | Encrypts leader election + DCS state traffic | Nodes cannot communicate — cluster loses quorum |

---

### REST API Authentication

Protects unsafe endpoints (POST, PUT, PATCH, DELETE) with HTTP Basic-auth.
Safe endpoints (GET) remain unauthenticated for health checks and monitoring.

#### Add-on configuration (this RPi)

```yaml
restapi_username: "patroni"
restapi_password: "your-secure-password"
```

#### Data node configuration (both PG nodes)

Add to `/etc/patroni/patroni.yml` under the `restapi:` section:

```yaml
restapi:
  listen: "0.0.0.0:8008"
  connect_address: "<node_ip>:8008"
  authentication:
    username: patroni
    password: your-secure-password
```

Then reload: `kill -HUP $(pgrep patroni)` — no restart needed.

#### Verification

```bash
# Unauthenticated GET (should work — safe endpoint)
curl -s http://<any_node>:8008/cluster

# Unauthenticated POST (should return 401)
curl -s -X POST http://<any_node>:8008/restart
# Expected: 401 Unauthorized

# Authenticated POST (should work)
curl -s -u patroni:your-secure-password -X POST http://<any_node>:8008/restart
# Expected: 200 OK (restarts PG gracefully)
```

#### patronictl after enabling auth

`patronictl` will need credentials. Add to patroni.yml:

```yaml
ctl:
  authentication:
    username: patroni
    password: your-secure-password
```

Or use environment variables:
```bash
export PATRONI_RESTAPI_USERNAME=patroni
export PATRONI_RESTAPI_PASSWORD=your-secure-password
patronictl -c /etc/patroni/patroni.yml list
```

---

### Raft Password (Traffic Encryption)

Encrypts all inter-node Raft communication (leader election, DCS state, configuration).
Without this, Raft messages are plaintext on the network.

#### Prerequisites

The `cryptography` Python package must be installed on **all 3 nodes**:

```bash
# On each data node (if not already present)
pip3 install cryptography
# Or: apt install python3-cryptography

# Verify
python3 -c "import cryptography; print(cryptography.__version__)"
```

The RPi add-on includes `cryptography` in its Docker image — no manual install needed.

#### Add-on configuration (this RPi)

```yaml
raft_password: "your-raft-encryption-password"
```

#### Data node configuration (both PG nodes)

Add to `/etc/patroni/patroni.yml` under the `raft:` section:

```yaml
raft:
  data_dir: /var/lib/patroni/raft
  self_addr: "<node_ip>:5010"
  partner_addrs:
    - "<other_node_ip>:5010"
    - "<rpi_ip>:5010"
  password: your-raft-encryption-password
```

#### Applying the change

**⚠️ All 3 nodes must use the same password before any node restarts.**

Recommended procedure:

1. Update the config file on **all 3 nodes** (both PG nodes + RPi add-on config)
2. Restart the standby PG node: `systemctl restart patroni`
3. Wait for it to rejoin the cluster (check `/cluster` endpoint)
4. Update and restart the RPi add-on (stop + start from HA UI)
5. Wait for it to rejoin
6. Restart the primary PG node: `systemctl restart patroni`
7. Verify cluster health: all 3 nodes streaming

**What happens if nodes have mismatched passwords:**
- Nodes with different passwords cannot establish Raft connections
- Cluster may lose quorum temporarily during the rolling restart
- Once all nodes share the same password and are restarted, cluster recovers

#### Verification

```bash
# Check all nodes are communicating
curl -s http://<primary_ip>:8008/cluster | python3 -m json.tool

# All 3 members should show state: "running" or "streaming"
# If a node shows state: "unknown" it may have a password mismatch
```

---

### Failsafe Mode

Not configured in this add-on — it's a **dynamic cluster setting** stored in the
Raft DCS, not in node-level config files.

Enable from any node with `patronictl` or the REST API:

```bash
# Via patronictl (with auth)
PATRONI_RESTAPI_USERNAME=patroni PATRONI_RESTAPI_PASSWORD=your-password \
  patronictl -c /etc/patroni/patroni.yml edit-config <scope> -s failsafe_mode=true --force

# Via REST API
curl -u patroni:your-password -X PATCH http://<primary_ip>:8008/config \
  -H "Content-Type: application/json" \
  -d '{"failsafe_mode": true}'
```

Failsafe prevents unnecessary primary demotion when Raft quorum is temporarily lost
but all members are actually reachable via REST API.

---

### Complete Hardened Configuration Reference

#### Data node (primary or standby) — `/etc/patroni/patroni.yml`

```yaml
scope: my-db-cluster
namespace: /db/
name: <unique-node-name>

raft:
  data_dir: /var/lib/patroni/raft
  self_addr: "<this_node_ip>:5010"
  partner_addrs:
    - "<other_data_node_ip>:5010"
    - "<rpi_ip>:5010"
  password: "<raft-password>"          # ← Hardening

restapi:
  listen: "0.0.0.0:8008"
  connect_address: "<this_node_ip>:8008"
  authentication:                       # ← Hardening
    username: patroni
    password: "<restapi-password>"

ctl:
  authentication:                       # ← For patronictl
    username: patroni
    password: "<restapi-password>"

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    synchronous_mode: true
    failsafe_mode: true                 # ← Hardening (dynamic, set once via API)
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        max_wal_senders: 5
        max_replication_slots: 5
        synchronous_commit: "on"
        synchronous_standby_names: "*"

  initdb:
    - encoding: UTF8
    - data-checksums

  pg_hba:
    - host replication replicator <subnet>/24 scram-sha-256
    - host all all <subnet>/24 scram-sha-256
    - local all all peer

postgresql:
  listen: "0.0.0.0:5432"
  connect_address: "<this_node_ip>:5432"
  data_dir: /var/lib/postgresql/15/main
  bin_dir: /usr/lib/postgresql/15/bin
  pgpass: /tmp/pgpass0
  authentication:
    replication:
      username: replicator
      password: "<replication-password>"
    superuser:
      username: postgres
      password: "<superuser-password>"

watchdog:
  mode: "off"

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false
```

#### RPi add-on configuration (HA UI)

```yaml
self_addr: "<rpi_ip>:5010"
partner_addrs:
  - "<data_node_1_ip>:5010"
  - "<data_node_2_ip>:5010"
scope: "my-db-cluster"
namespace: "/db/"
replication_username: "replicator"
replication_password: "<replication-password>"
superuser_username: "postgres"
superuser_password: "<superuser-password>"
log_level: "INFO"
pg_version: "15"
restapi_username: "patroni"
restapi_password: "<restapi-password>"
raft_password: "<raft-password>"
```

---

### Security Checklist

- [ ] REST API auth enabled on all 3 nodes (same username/password)
- [ ] Raft password set on all 3 nodes (identical value)
- [ ] `cryptography` Python package installed on data nodes
- [ ] `failsafe_mode` enabled (dynamic config, set once)
- [ ] Credentials stored in a secrets manager (not plaintext in docs)
- [ ] `patronictl` configured with auth (ctl.authentication or env vars)
- [ ] HAProxy health check uses GET `/primary` (doesn't need auth)
- [ ] Monitoring uses GET endpoints only (no auth needed for read)
