# PostgreSQL Clusters Analysis - CPGO to CNPG Migration

**Generated:** 2025-11-02
**Purpose:** Analyze current PostgreSQL clusters to plan migration from Crunchy Postgres Operator to CloudNativePG

---

## Executive Summary

- **Total Clusters:** 9 (across 5 namespaces)
- **Total Data Size:** ~2.9 GB (actual database data)
- **Total Storage Used:** ~17.8 GB (with WAL, etc.)
- **Total PVC Allocated:** 135 GB (27 PVCs × 5Gi each)
- **Storage Waste:** ~117 GB (87% unused)
- **Migration Complexity:** LOW - all databases are small, largest is 2.5 GB

**Recommendation:** ✅ **Proceed with CNPG migration** - databases are small enough that full backups daily are efficient, and WAL archiving provides better granularity than hourly incrementals.

---

## Current Cluster Details

### Storage Overview

| Namespace | Cluster | DB Size | Total /pgdata | Replicas | Total Used (all replicas) | PVC Allocated |
|-----------|---------|---------|---------------|----------|---------------------------|---------------|
| downloads | prowlarr | 51 MB | 308 MB | 3 | 0.90 GB | 5Gi |
| downloads | radarr | 148 MB | 473 MB | 3 | 1.38 GB | 5Gi |
| downloads | sonarr | 147 MB | 454 MB | 3 | 1.32 GB | 5Gi |
| media | jellyseerr | 33 MB | 285 MB | 3 | 0.83 GB | 5Gi |
| media | jellystat | 238 MB | 531 MB | 3 | 1.55 GB | 5Gi |
| observability | grafana | 47 MB | 323 MB | 3 | 0.94 GB | 5Gi |
| security | **authentik** | **2.2 GB** | **2.5 GB** | 3 | **7.22 GB** | 5Gi |
| self-hosted | atuin | 31 MB | 261 MB | 3 | 0.76 GB | 5Gi |
| self-hosted | miniflux | 103 MB | 393 MB | 3 | 1.14 GB | 5Gi |
| **TOTAL** | **9 clusters** | **~2.9 GB** | **~6.0 GB** | | **~17.8 GB** | **135 GB** |

### Resource Usage (CPU & Memory)

**Current actual usage across all pods (sampled):**

| Namespace | Cluster | Sample CPU Range | Sample Memory Range | Notes |
|-----------|---------|------------------|---------------------|-------|
| downloads | prowlarr | 10-15m | 81-129 Mi | Very light |
| downloads | radarr | 11-15m | 125-223 Mi | Light |
| downloads | sonarr | 6-35m | 100-212 Mi | Variable |
| media | jellyseerr | 2-25m | 75-120 Mi | Very light |
| media | jellystat | 3-17m | 167-237 Mi | Light |
| observability | grafana | 8-84m | 94-176 Mi | Spiky (queries) |
| security | authentik | 5-44m | 106-254 Mi | Moderate |
| self-hosted | atuin | 1-19m | 74-97 Mi | Very light |
| self-hosted | miniflux | 2-17m | 117-157 Mi | Light |

**Key observations:**
- Most clusters use < 50m CPU and < 250 Mi RAM
- Grafana has occasional spikes (up to 84m CPU)
- Memory usage is consistently low (< 300 Mi)
- Current CPGO has **no resource limits set** (all N/A)

---

## CNPG Migration Recommendations

### Recommended Resource Configuration per Cluster

| Cluster | CNPG_REQUESTS_CPU | CNPG_LIMITS_MEMORY | CNPG_SIZE | CNPG_REPLICAS | Reasoning |
|---------|-------------------|--------------------|-----------|--------------|-----------|
| **authentik** | `500m` | `2Gi` | `5Gi` | `3` | Largest DB, needs headroom |
| **grafana** | `200m` | `1Gi` | `2Gi` | `3` | Spiky queries, moderate size |
| **radarr** | `100m` | `512Mi` | `2Gi` | `3` | Small DB, stable usage |
| **sonarr** | `100m` | `512Mi` | `2Gi` | `3` | Small DB, stable usage |
| **jellystat** | `100m` | `512Mi` | `2Gi` | `3` | Medium-small, growing |
| **prowlarr** | `100m` | `512Mi` | `2Gi` | `3` | Small DB, very light |
| **jellyseerr** | `100m` | `512Mi` | `2Gi` | `3` | Small DB, very light |
| **miniflux** | `100m` | `512Mi` | `2Gi` | `3` | Small DB, stable |
| **atuin** | `100m` | `512Mi` | `2Gi` | `3` | Smallest, minimal usage |

**Notes:**
- Keeping 3 replicas (same as CPGO) for proper HA quorum
- Set actual resource limits (CPGO didn't have any)
- Conservative limits with 2-4x headroom for growth
- All configs use `local-hostpath` storage class

### Storage Optimization

| Metric | Current (CPGO) | Proposed (CNPG) | Savings |
|--------|----------------|-----------------|---------|
| **Total PVCs** | 27 (9 clusters × 3 replicas) | 27 (9 clusters × 3 replicas) | Same count |
| **Per-cluster PVC size** | 5Gi (all) | 2-5Gi (optimized) | Variable |
| **Total PVC allocation** | 135 GB | ~81 GB | **-40%** (54 GB saved) |
| **Actual usage** | ~18 GB | ~18 GB | Same |
| **Waste factor** | 87% | 78% | Better utilization |

---

## Backup Strategy Comparison

### Current CPGO Backup Schedule

```yaml
schedules:
  full: "30 1 * * 0"          # Weekly - Sunday 01:30
  differential: "30 1 * * 1-6" # Daily - Mon-Sat 01:30
  incremental: "30 3-23 * * *" # Hourly - 20x per day
```

**Characteristics:**
- 1 full + 6 differential + 140 incremental backups per week
- pgBackRest with bzip2 compression and bz2 level 9
- Complex restore chain (full → differential → incrementals)
- Storage efficient for large DBs (incrementals are small)

### Proposed CNPG Backup Strategy

```yaml
schedule: "@daily"  # Or "0 1 * * *" for 01:00 daily
```

**Characteristics:**
- 1 full backup per day
- Continuous WAL archiving (every 16MB segment, ~minutes)
- Point-in-Time Recovery (PITR) to the second
- Simple restore (latest full + WAL replay)
- Better for small DBs (< 5GB)

### Backup Storage Estimation (7 day retention)

| Cluster | /pgdata Size | Compressed Backup (~50%) | 7 Daily Backups | WAL (7 days) | Total |
|---------|--------------|--------------------------|-----------------|--------------|-------|
| authentik | 2.5 GB | 1.25 GB | 8.75 GB | ~500 MB | ~9.3 GB |
| radarr | 473 MB | 237 MB | 1.66 GB | ~100 MB | ~1.8 GB |
| sonarr | 454 MB | 227 MB | 1.59 GB | ~100 MB | ~1.7 GB |
| jellystat | 531 MB | 266 MB | 1.86 GB | ~120 MB | ~2.0 GB |
| grafana | 323 MB | 162 MB | 1.13 GB | ~80 MB | ~1.2 GB |
| prowlarr | 308 MB | 154 MB | 1.08 GB | ~60 MB | ~1.1 GB |
| jellyseerr | 285 MB | 143 MB | 1.00 GB | ~50 MB | ~1.1 GB |
| miniflux | 393 MB | 197 MB | 1.38 GB | ~80 MB | ~1.5 GB |
| atuin | 261 MB | 131 MB | 0.92 GB | ~50 MB | ~1.0 GB |
| **TOTAL** | **~6.0 GB** | **~3.0 GB** | **~21 GB** | **~1.1 GB** | **~22 GB** |

**Backup location:** S3 bucket `s3://cnpg/` with compression (bzip2) and encryption (AES256)

---

## Migration Strategy

### Phase 1: Preparation
1. ✅ Install CNPG operator (keep CPGO running)
2. ✅ Verify components in `/kubernetes/components/cnpg/`
3. Test with smallest cluster first (atuin - 261MB)

### Phase 2: Pilot Migration (Week 1)
**Order:** Start with smallest, least critical clusters

1. **atuin** (261 MB) - least critical
2. **jellyseerr** (285 MB) - can rebuild from source
3. **prowlarr** (308 MB) - can rebuild from source

**Per-cluster process:**
```bash
# Backup with CPGO
kubectl cnpg backup <namespace> <cluster>

# Export data
pg_dump > backup.sql

# Deploy CNPG cluster
# Restore data
# Verify
# Delete CPGO cluster
```

### Phase 3: Main Migration (Week 2-3)
4. miniflux (393 MB)
5. grafana (323 MB) - **backup dashboards first!**
6. sonarr (454 MB)
7. radarr (473 MB)
8. jellystat (531 MB)

### Phase 4: Large Cluster (Week 4)
9. **authentik** (2.5 GB) - most critical, save for last
   - Test on staging first
   - Schedule maintenance window
   - Backup OIDC configuration

### Phase 5: Cleanup
- Remove CPGO operator
- Archive old backups
- Update documentation

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| Data loss during migration | High | Always pg_dump before migration, keep CPGO backups for 30d |
| Downtime for apps | Medium | Migrate during low-traffic hours, keep CPGO running in parallel |
| Backup restore issues | Medium | Test restore procedure on pilot clusters first |
| CNPG operator bugs | Low | CNPG is mature (CNCF Sandbox project), large community |
| Resource exhaustion | Low | All clusters are small, ample CPU/memory available |
| Storage issues | Low | Reducing total PVC allocation, more efficient usage |

---

## Why CNPG is Better for This Use Case

### ✅ Advantages
1. **WAL archiving > hourly incrementals** - For DBs < 5GB, continuous WAL archiving provides better PITR than incrementals
2. **Simpler architecture** - One operator, less complexity than CPGO + pgBackRest
3. **Better resource efficiency** - Lighter operator, can reduce PVC sizes
4. **CNCF project** - Better long-term support, active development
5. **Native Kubernetes patterns** - More cloud-native design
6. **Better monitoring** - Native PodMonitor support for Prometheus

### ❌ What You Lose (but doesn't matter here)
1. **Differential/incremental backups** - Not needed for small DBs
2. **pgBackRest features** - Barman is simpler but sufficient
3. **Commercial support** - Crunchy Data offers paid support (not needed for home-ops)

### 💰 Cost/Benefit
- **Storage savings:** ~81 GB PVC space freed
- **Operational simplicity:** Fewer moving parts
- **Migration effort:** ~4 weeks part-time work
- **Risk:** Low (small DBs, can rollback easily)

**Verdict:** Migration is worth it for this environment.

---

## Example CNPG Configuration

Based on your existing `/kubernetes/components/cnpg/` structure:

```yaml
# In app's kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: miniflux-db
  namespace: flux-system
spec:
  path: ./kubernetes/apps/self-hosted/miniflux
  dependsOn:
    - name: cloudnative-pg
      namespace: database
  postBuild:
    substitute:
      APP: miniflux
      CNPG_REPLICAS: '3'
      CNPG_IMAGE: ghcr.io/cloudnative-pg/postgresql:17.6-standard-trixie@sha256:e185037ad4c926fece1d3cfd1ec99680a862d7d02b160354e263a04a2d46b5f5
      CNPG_SIZE: 2Gi
      CNPG_STORAGECLASS: local-hostpath
      CNPG_REQUESTS_CPU: 100m
      CNPG_LIMITS_MEMORY: 512Mi
      CNPG_MAX_CONNECTIONS: '100'
      CNPG_SHARED_BUFFERS: 128MB
  components:
    - ../../../../components/cnpg/backup
```

---

## Next Steps

1. [ ] Review this analysis
2. [ ] Approve migration plan
3. [ ] Schedule Phase 1 (pilot with atuin)
4. [ ] Document rollback procedures
5. [ ] Begin migration

---

## References

- CNPG Documentation: https://cloudnative-pg.io/documentation/
- Barman Cloud Plugin: https://cloudnative-pg.io/plugin-barman-cloud/
- Current CPGO version: 5.8.4
- Components location: `/kubernetes/components/cnpg/`
