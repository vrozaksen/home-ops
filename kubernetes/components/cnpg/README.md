# CloudNative-PG Components

## Overview

CloudNative-PG provides Kubernetes-native PostgreSQL clusters with automated backups, replication, and disaster recovery.

**Component structure:**
```
base → initdb (one-time: create empty DB)
     → restore (permanent: restore from backup)
```

- **`base`** - Core cluster + PgBouncer pooler + backup configuration
- **`initdb`** - Bootstrap patch for new empty databases ⚠️ **Temporary**
- **`restore`** - Bootstrap patch for restoring from backup ✅ **Production**

## Quick Start

### Option A: New database
1. Deploy with `../../../components/cnpg/initdb`
2. Wait 24h for first backup
3. Switch to `../../../components/cnpg/restore` ✅ **Keep permanently**

### Option B: Restore existing database
1. Deploy with `../../../components/cnpg/restore` ✅ **Keep permanently**

### Why use `restore` permanently?
- ✅ Automatic disaster recovery
- ✅ Infrastructure as code - recreate = auto-restore
- ✅ Production safety - always recovers to last good state

---

## Prerequisites

**Bitwarden secret:** `cloudnative-pg`
- `POSTGRES_SUPER_USER` - Superuser username (default: `postgres`)
- `POSTGRES_SUPER_PASS` - Superuser password (strong random)
- `AWS_ACCESS_KEY_ID` - S3 backup access key
- `AWS_SECRET_ACCESS_KEY` - S3 backup secret key

---

## Application Connection

**CNPG automatically creates:**
1. User: `app` (or `${APP}` with `CNPG_DATABASE` override)
2. Database: `app` (or `${CNPG_DATABASE}`)
3. Secret: `postgres-${APP}-app` with auto-generated credentials

**Recommended: Use pre-built URI**
```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: postgres-${APP}-app
        key: uri
```

**Alternative: Individual fields**
```yaml
env:
  - name: DB_HOST
    valueFrom:
      secretKeyRef:
        name: postgres-${APP}-app
        key: host  # postgres-${APP}-rw (or pooler-${APP}-rw if using pooler)
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: postgres-${APP}-app
        key: username
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: postgres-${APP}-app
        key: password
  # Also available: dbname, port, pgpass, jdbc-uri
```

**Note:** The `host` key points to direct PostgreSQL service. To use PgBouncer, override with `value: pooler-${APP}-rw`.

---

## PgBouncer Connection Pooling

**When to use:**
- ✅ Many connections (>50)
- ✅ Short-lived connections (serverless, lambdas)
- ✅ Transaction-level isolation required (Authentik, Django)
- ❌ NOT needed for most homelab apps (<20 idle connections)

**Service endpoints:**
- **Direct PostgreSQL:** `postgres-${APP}-rw` (port 5432)
- **PgBouncer pooler:** `pooler-${APP}-rw` (port 5432)

**Pool modes:**

| Mode | Use Case | Limitations |
|------|----------|-------------|
| `session` (default) | Most apps | None |
| `transaction` | Authentik, Django | No session features (SET, LISTEN/NOTIFY) |
| `statement` | Rare | No transactions, prepared statements |

**Example: Authentik with transaction mode**

```yaml
# ks.yaml
components:
  - ../../../components/cnpg/restore
postBuild:
  substitute:
    APP: authentik
    CNPG_POOLER_MODE: transaction
```

```yaml
# helmrelease.yaml - override host to use pooler
env:
  - name: DB_HOST
    value: pooler-authentik-rw  # Override to use PgBouncer
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: postgres-authentik-app
        key: username
```

---

## Configuration Variables

### Required
```yaml
dependsOn:
  - name: cloudnative-pg
    namespace: database
  - name: plugin-barman-cloud
    namespace: database
postBuild:
  substitute:
    APP: myapp  # Required
```

### Core Settings (with defaults)
```yaml
CNPG_REPLICAS: '3'                # Instances (3 = HA quorum)
CNPG_SIZE: 2Gi                    # PVC size (2Gi small, 5Gi large)
CNPG_STORAGECLASS: local-hostpath # Storage class
```

### Resources (Burstable QoS - recommended for most apps)
```yaml
CNPG_REQUESTS_CPU: 25m            # Low reservation, can burst
CNPG_REQUESTS_MEMORY: 256Mi       # Minimal reservation
CNPG_LIMITS_MEMORY: 512Mi         # Can burst to 2x memory
```

### PostgreSQL Tuning
```yaml
CNPG_MAX_CONNECTIONS: '100'           # Connection limit
CNPG_SHARED_BUFFERS: 128MB            # ~25% of memory
CNPG_EFFECTIVE_CACHE_SIZE: 512MB      # Expected OS cache (~75%)
CNPG_WORK_MEM: 4MB                    # Per-operation memory
CNPG_MAINTENANCE_WORK_MEM: 64MB       # VACUUM, CREATE INDEX
CNPG_RANDOM_PAGE_COST: '1.1'          # SSD optimized
CNPG_WAL_BUFFERS: 16MB                # WAL buffer size
```

### Synchronous Replication (recommended for production)
```yaml
CNPG_SYNC_METHOD: any             # 'any' = quorum (default), '' = async only
CNPG_SYNC_NUMBER: '1'             # Min standby replicas for sync
CNPG_SYNC_DURABILITY: preferred   # 'preferred' = self-healing (recommended)
```

### PgBouncer Pooler
```yaml
CNPG_POOLER_MODE: session              # session, transaction, statement
CNPG_POOLER_INSTANCES: '2'             # Number of pooler pods
```

### Advanced
```yaml
CNPG_IMAGE: ghcr.io/cloudnative-pg/postgresql  # Override image (version in cluster.yaml)
CNPG_VERSION: '18.1-system-trixie'             # PostgreSQL version
CNPG_DATABASE: mydb                            # Override database name (default: app)
CNPG_DISABLED_SERVICES: "['ro', 'r']"          # Disable read-only services
```

---

## Deployment Profiles

### Profile 1: HA with sync replication (RECOMMENDED)
```yaml
CNPG_REPLICAS: '3'
CNPG_SYNC_METHOD: any
CNPG_SYNC_NUMBER: '1'
CNPG_SYNC_DURABILITY: preferred
```
✅ Near-zero data loss, automatic failover, self-healing
🎯 Use for: All production apps (authentik, grafana, *arr, etc.)

### Profile 2: Single-node (dev/testing only)
```yaml
CNPG_REPLICAS: '1'
CNPG_SYNC_METHOD: ''  # Must be empty
```
❌ No HA, single point of failure
🎯 Use for: Development, testing, non-critical data

---

## Resource Sizing Guide

**Default: Burstable QoS** (ideal for idle databases)
- Requests: CPU 25m, Memory 256Mi (minimal reservation)
- Limits: Memory 512Mi (can burst 2x), CPU unlimited

**Custom sizing examples:**
```yaml
# Small DBs (<500MB data)
CNPG_REQUESTS_CPU: 25m
CNPG_LIMITS_MEMORY: 512Mi

# Medium DBs (500MB-2GB)
CNPG_REQUESTS_CPU: 100m
CNPG_REQUESTS_MEMORY: 512Mi
CNPG_LIMITS_MEMORY: 1Gi

# Large DBs (>2GB)
CNPG_REQUESTS_CPU: 200m
CNPG_REQUESTS_MEMORY: 1Gi
CNPG_LIMITS_MEMORY: 2Gi
CNPG_MAX_CONNECTIONS: '300'
CNPG_SHARED_BUFFERS: 512MB
CNPG_EFFECTIVE_CACHE_SIZE: 1536MB
```

💡 **Why Burstable?** Idle DBs sit at low usage but need bursts for VACUUM, backups, indexing.

---

## Usage Examples

### Example 1: New database (initdb → restore workflow)

**Step 1: Initial deployment**
```yaml
# kubernetes/apps/media/miniflux/ks.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: miniflux
spec:
  components:
    - ../../../components/cnpg/initdb  # ⚠️ Temporary
  dependsOn:
    - name: cloudnative-pg
      namespace: database
    - name: plugin-barman-cloud
      namespace: database
  postBuild:
    substitute:
      APP: miniflux
      CNPG_SIZE: 2Gi
  targetNamespace: media
```

**Step 2: After 24h (first backup exists), switch to restore**
```yaml
spec:
  components:
    - ../../../components/cnpg/restore  # ✅ Keep permanently
```

### Example 2: Restore existing database
```yaml
# kubernetes/apps/security/authentik/ks.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: authentik
spec:
  components:
    - ../../../components/cnpg/restore  # ✅ Production config
  dependsOn:
    - name: cloudnative-pg
      namespace: database
    - name: plugin-barman-cloud
      namespace: database
  postBuild:
    substitute:
      APP: authentik
      CNPG_SIZE: 5Gi
      CNPG_POOLER_MODE: transaction  # Required by Authentik
  targetNamespace: security
```

### Example 3: Large database with custom tuning
```yaml
# kubernetes/apps/observability/grafana/ks.yaml
spec:
  components:
    - ../../../components/cnpg/restore
  postBuild:
    substitute:
      APP: grafana
      CNPG_REPLICAS: '3'
      CNPG_SIZE: 5Gi
      CNPG_REQUESTS_CPU: 100m
      CNPG_REQUESTS_MEMORY: 512Mi
      CNPG_LIMITS_MEMORY: 1Gi
      CNPG_MAX_CONNECTIONS: '200'
      CNPG_SHARED_BUFFERS: 256MB
```

---

## Health Checks

```yaml
healthCheckExprs:
  - apiVersion: postgresql.cnpg.io/v1
    kind: Cluster
    failed: status.conditions.filter(e, e.type == 'Ready').all(e, e.status == 'False')
    current: status.conditions.filter(e, e.type == 'Ready').all(e, e.status == 'True')
```

---

## Disaster Recovery

For Point-In-Time Recovery (PITR) and advanced disaster recovery procedures, see **[RECOVERY.md](./RECOVERY.md)**.

---

## FAQ

**Q: Should I keep `restore` or `initdb` permanently?**
A: **Always use `restore` for production.** Use `initdb` only temporarily for new databases, then switch to `restore` after first backup.

**Q: What if I keep `initdb` permanently?**
A: If cluster gets deleted, it recreates EMPTY instead of restoring from backup. Data loss!

**Q: Does `restore` restore on every Flux reconcile?**
A: No. `bootstrap.recovery` only runs when cluster is first created. After that, cluster operates normally.

**Q: What if backup doesn't exist when using `restore`?**
A: Cluster fails to start. Use `initdb` first, wait for backup, then switch to `restore`.

**Q: Can I change from `initdb` to `restore` without downtime?**
A: Yes. Component change only matters when cluster is recreated. Running cluster is unaffected.

**Q: How do I know when to switch?**
A: After 24 hours. Check: `kubectl get backup -n <namespace>`

**Q: How do I use PgBouncer?**
A: Set `CNPG_POOLER_MODE` if needed (default `session` works for most apps). Override application's `DB_HOST` to `pooler-${APP}-rw` instead of using the auto-generated `postgres-${APP}-app` secret's `host` key.

---

## High Availability

- ✅ Automatic failover - operator promotes standby with lowest lag
- ✅ Applications use `-rw` service - auto-updated to new primary
- ✅ Synchronous replication recommended - minimal overhead, near-zero data loss
- 📚 [Failure modes docs](https://cloudnative-pg.io/documentation/current/failure_modes/)

**Why sync replication for production?**
- 💰 Free protection - you already have 3 replicas
- ⚡ Low overhead - ~1-2ms write latency increase
- 🛡️ Data safety - near RPO=0, no data loss on failover
- 🔄 Self-healing - `preferred` mode keeps cluster writable even if standbys down
