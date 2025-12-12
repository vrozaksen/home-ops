# Disaster Recovery: Point-In-Time Recovery (PITR)

Point-In-Time Recovery allows you to restore a PostgreSQL cluster to any specific moment in time, not just the latest backup. This is critical for scenarios like:

- 🔥 Accidental data deletion (recover to moment before DELETE)
- 🐛 Bad migration or schema change (rollback to pre-migration state)
- 🔓 Security breach (restore to moment before compromise)
- 🧪 Testing rollback scenarios

## How PITR Works

CNPG uses base backups + Write-Ahead Logs (WAL) to replay transactions up to a specific point:
1. Restore from nearest base backup (before target time)
2. Replay WAL archives up to specified recovery target
3. Stop at exact moment (timestamp, transaction ID, or restore point)

## Prerequisites

- ✅ Component `../../../components/cnpg/restore` in use
- ✅ S3 backups enabled (automatic with `base` component)
- ✅ WAL archiving enabled via `plugin-barman-cloud` (automatic)

---

## Step-by-Step: PITR Recovery

### Step 1: Identify Recovery Target

**Find timestamp of last known good state:**

```bash
# Check application logs for when issue occurred
kubectl logs -n development forgejo-xxx --since=2h | grep ERROR

# Or check PostgreSQL logs
kubectl logs -n development postgres-forgejo-1 | grep "2025-12-12"

# Determine target time (RFC 3339 format)
TARGET_TIME="2025-12-12T14:30:00+00:00"  # Before the incident
```

**Or use transaction ID if known:**
```bash
# From PostgreSQL logs or monitoring
TARGET_XID="123456789"
```

---

### Step 2: Delete Existing Cluster

⚠️ **WARNING:** This deletes the current cluster. Applications will be down until recovery completes.

```bash
# Suspend Flux reconciliation first (prevents auto-recreation)
flux suspend kustomization forgejo -n flux-system

# Delete the cluster (PVCs are preserved by default)
kubectl delete cluster postgres-forgejo -n development

# Wait for cluster to be fully deleted
kubectl wait --for=delete cluster/postgres-forgejo -n development --timeout=5m
```

---

### Step 3: Configure Recovery Target for This App Only

⚠️ **IMPORTANT:** Do NOT modify the global `restore` component. Instead, add a per-app patch to the Flux Kustomization.

Edit your app's `ks.yaml` to add a `patches` section:

**Option A: Recover to specific timestamp (most common)**

```yaml
# kubernetes/apps/development/forgejo/ks.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: forgejo
spec:
  components:
    - ../../../components/cnpg/restore
  # Add patches section to override ONLY this app's cluster:
  patches:
    - patch: |-
        apiVersion: postgresql.cnpg.io/v1
        kind: Cluster
        metadata:
          name: postgres-forgejo
          annotations:
            cnpg.io/skipEmptyWalArchiveCheck: 'enabled'
        spec:
          bootstrap:
            recovery:
              database: forgejo
              owner: forgejo
              source: source
              recoveryTarget:
                targetTime: "2025-12-12T14:30:00+00:00"
          externalClusters:
            - name: source
              plugin:
                name: barman-cloud.cloudnative-pg.io
                parameters:
                  barmanObjectName: postgres-forgejo
                  serverName: postgres-forgejo
      target:
        kind: Cluster
        name: postgres-forgejo
  postBuild:
    substitute:
      APP: forgejo
      CNPG_SIZE: 5Gi
```

**Option B: Recover to transaction ID**
```yaml
  patches:
    - patch: |-
        apiVersion: postgresql.cnpg.io/v1
        kind: Cluster
        metadata:
          name: postgres-forgejo
          annotations:
            cnpg.io/skipEmptyWalArchiveCheck: 'enabled'
        spec:
          bootstrap:
            recovery:
              database: forgejo
              owner: forgejo
              source: source
              recoveryTarget:
                targetXID: "123456789"
                backupID: postgres-forgejo-backup-20251210000000
          externalClusters:
            - name: source
              plugin:
                name: barman-cloud.cloudnative-pg.io
                parameters:
                  barmanObjectName: postgres-forgejo
                  serverName: postgres-forgejo
      target:
        kind: Cluster
        name: postgres-forgejo
```

**Option C: Recover to named restore point**
```yaml
  patches:
    - patch: |-
        apiVersion: postgresql.cnpg.io/v1
        kind: Cluster
        metadata:
          name: postgres-forgejo
          annotations:
            cnpg.io/skipEmptyWalArchiveCheck: 'enabled'
        spec:
          bootstrap:
            recovery:
              database: forgejo
              owner: forgejo
              source: source
              recoveryTarget:
                targetName: "before-migration"
                backupID: postgres-forgejo-backup-20251210000000
          externalClusters:
            - name: source
              plugin:
                name: barman-cloud.cloudnative-pg.io
                parameters:
                  barmanObjectName: postgres-forgejo
                  serverName: postgres-forgejo
      target:
        kind: Cluster
        name: postgres-forgejo
```

**Option D: Recover to earliest consistent state**
```yaml
  patches:
    - patch: |-
        apiVersion: postgresql.cnpg.io/v1
        kind: Cluster
        metadata:
          name: postgres-forgejo
          annotations:
            cnpg.io/skipEmptyWalArchiveCheck: 'enabled'
        spec:
          bootstrap:
            recovery:
              database: forgejo
              owner: forgejo
              source: source
              recoveryTarget:
                targetImmediate: true
          externalClusters:
            - name: source
              plugin:
                name: barman-cloud.cloudnative-pg.io
                parameters:
                  barmanObjectName: postgres-forgejo
                  serverName: postgres-forgejo
      target:
        kind: Cluster
        name: postgres-forgejo
```

**Why this approach?**
- ✅ Only affects THIS app's cluster
- ✅ Other apps using `cnpg/restore` are unaffected
- ✅ Easy to add/remove - just edit ks.yaml
- ✅ Git history shows PITR attempt for specific app

---

### Step 4: Resume Flux and Trigger Recovery

```bash
# Resume Flux to recreate cluster with PITR
flux resume kustomization forgejo -n flux-system

# Watch recovery progress
kubectl get cluster postgres-forgejo -n development -w

# Check recovery logs
kubectl logs -n development postgres-forgejo-1 -f | grep recovery
```

Expected output:
```
LOG:  starting point-in-time recovery to 2025-12-12 14:30:00+00
LOG:  restored log file "000000010000000000000042" from archive
LOG:  recovery stopping before commit of transaction 123456789
LOG:  recovery has paused
LOG:  selected new timeline ID: 2
LOG:  archive recovery complete
```

---

### Step 5: Verify Recovery

```bash
# Check cluster is ready
kubectl get cluster postgres-forgejo -n development
# Should show: STATUS: Cluster in healthy state

# Check database content
kubectl exec -n development postgres-forgejo-1 -- psql -U app -d app -c "SELECT NOW();"

# Verify data is from before incident
kubectl exec -n development postgres-forgejo-1 -- psql -U app -d app -c \
  "SELECT COUNT(*) FROM critical_table;"
```

---

### Step 6: Return to Normal Operation

**IMPORTANT:** Remove the `patches` section from ks.yaml to prevent PITR on next recreate.

```bash
# Edit kubernetes/apps/development/forgejo/ks.yaml
# Remove the entire patches section you added in Step 3

# Example: Remove these lines:
# patches:
#   - patch: |-
#       apiVersion: postgresql.cnpg.io/v1
#       ...

# Commit the change
git add kubernetes/apps/development/forgejo/ks.yaml
git commit -m "Remove PITR patch after successful recovery"
git push
```

**Why?** If you leave the `patches` section in place, next cluster recreation will PITR again, losing newer data!

---

## Recovery Target Options

| Target Type | When to Use | Requires backupID? |
|-------------|-------------|-------------------|
| `targetTime` | Most common - rollback to timestamp | ❌ No (auto-finds backup) |
| `targetXID` | Rollback to specific transaction | ✅ Yes |
| `targetName` | Pre-created restore point | ✅ Yes |
| `targetLSN` | Rollback to WAL position | ❌ No (auto-finds backup) |
| `targetImmediate` | Earliest consistent state | ❌ No |

---

## Finding Backup ID

```bash
# List available backups
kubectl get backup -n development -l cnpg.io/cluster=postgres-forgejo

# Example output:
NAME                                    AGE   CLUSTER             METHOD   PHASE
postgres-forgejo-backup-20251210000000  2d    postgres-forgejo  plugin   completed
postgres-forgejo-backup-20251211000000  1d    postgres-forgejo  plugin   completed
postgres-forgejo-backup-20251212000000  16h   postgres-forgejo  plugin   completed

# Use the backup name in recoveryTarget.backupID
```

---

## Troubleshooting PITR

**Issue: "no backup found for target time"**
- Solution: Check backups exist before target time with `kubectl get backup -n <namespace>`

**Issue: "requested timeline is not a child of this server's history"**
- Solution: Timeline mismatch - verify `serverName` in externalClusters matches original cluster

**Issue: Recovery stuck at "waiting for WAL"**
- Solution: Target time may be beyond available WAL archives. Check S3 bucket for WAL files.

**Issue: Cluster recreates but ignores recoveryTarget**
- Solution: Ensure patch.yaml is in `restore` component, not `initdb`

---

## Advanced: Creating Named Restore Points

For planned maintenance, create restore points BEFORE risky operations:

```bash
# Connect to primary
kubectl exec -n development postgres-forgejo-1 -- psql -U postgres -c \
  "SELECT pg_create_restore_point('before-schema-migration');"

# Later, if needed, recover to this point
recoveryTarget:
  targetName: "before-schema-migration"
  backupID: postgres-forgejo-backup-20251212000000
```

---

## Real-World Examples

### Example 1: Accidental table drop

**Scenario:** Developer accidentally ran `DROP TABLE users;` at 14:45 UTC

```bash
# 1. Find last good state (14:44 UTC)
TARGET_TIME="2025-12-12T14:44:00+00:00"

# 2. Suspend Flux
flux suspend kustomization myapp -n flux-system

# 3. Delete cluster
kubectl delete cluster postgres-myapp -n myapp

# 4. Edit app's ks.yaml to add PITR patch
# kubernetes/apps/production/myapp/ks.yaml
# Add patches section:
cat <<EOF >> kubernetes/apps/production/myapp/ks.yaml
  patches:
    - patch: |-
        apiVersion: postgresql.cnpg.io/v1
        kind: Cluster
        metadata:
          name: postgres-myapp
        spec:
          bootstrap:
            recovery:
              recoveryTarget:
                targetTime: "2025-12-12T14:44:00+00:00"
      target:
        kind: Cluster
        name: postgres-myapp
EOF

# 5. Commit and push
git add kubernetes/apps/production/myapp/ks.yaml
git commit -m "Add PITR recovery for accidental table drop"
git push

# 6. Resume Flux
flux resume kustomization myapp -n flux-system

# 7. Wait for recovery, verify, then remove patches section from ks.yaml
```

---

### Example 2: Bad migration rollback

**Scenario:** Database migration corrupted data, need to rollback

```bash
# 1. Create restore point BEFORE migration (proactive)
kubectl exec -n production postgres-api-1 -- psql -U postgres -c \
  "SELECT pg_create_restore_point('before-v2-migration');"

# 2. Find backup ID taken before restore point
kubectl get backup -n production -l cnpg.io/cluster=postgres-api
# Note the backup name, e.g., postgres-api-backup-20251212120000

# 3. If migration fails, add PITR patch to ks.yaml
# kubernetes/apps/production/api/ks.yaml
# Add:
# patches:
#   - patch: |-
#       apiVersion: postgresql.cnpg.io/v1
#       kind: Cluster
#       metadata:
#         name: postgres-api
#       spec:
#         bootstrap:
#           recovery:
#             recoveryTarget:
#               targetName: "before-v2-migration"
#               backupID: postgres-api-backup-20251212120000
#     target:
#       kind: Cluster
#       name: postgres-api

# 4. Delete and recreate cluster with PITR
flux suspend kustomization api -n flux-system
kubectl delete cluster postgres-api -n production
git add kubernetes/apps/production/api/ks.yaml
git commit -m "PITR: rollback to before-v2-migration"
git push
flux resume kustomization api -n flux-system

# 5. After verification, remove patches section from ks.yaml
```

---

### Example 3: Ransomware recovery

**Scenario:** Detected ransomware encryption at 03:15 UTC, last known good state at 02:50 UTC

```bash
# 1. Identify attack vector and patch vulnerability first!

# 2. Recover to pre-attack state
TARGET_TIME="2025-12-12T02:50:00+00:00"

# 3. Follow standard PITR steps with targetTime

# 4. After recovery, audit logs to find attack vector:
kubectl exec -n production postgres-db-1 -- psql -U postgres -c \
  "SELECT * FROM pg_stat_activity WHERE query_start < '2025-12-12 03:15:00';"
```

---

## Best Practices

1. **Test PITR regularly** - Don't wait for disaster to learn the process
2. **Create named restore points** before risky operations (migrations, schema changes)
3. **Monitor WAL archiving** - Ensure WAL files are being uploaded to S3
4. **Document recovery procedures** - Keep runbook updated with app-specific steps
5. **Remove recoveryTarget** after successful PITR - Prevent accidental re-recovery
6. **Verify backup retention** - Ensure backups cover your desired recovery window

---

## Related Documentation

- [CloudNativePG Recovery Documentation](https://cloudnative-pg.io/documentation/current/recovery/)
- [PostgreSQL PITR](https://www.postgresql.org/docs/current/continuous-archiving.html)
- [Main CNPG README](./README.md)
