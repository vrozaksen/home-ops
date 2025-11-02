# CloudNativePG Operator Setup

This directory contains the CloudNativePG operator and plugin setup for PostgreSQL clusters.

## Structure

```
cloudnative-pg/
├── README.md                  # This file
├── ks.yaml                    # Main Flux Kustomizations (operator + plugin)
├── app/                       # CNPG operator deployment
│   ├── helmrelease.yaml       # Operator Helm chart (manages CRDs)
│   ├── prometheusrule.yaml    # Alert rules
│   └── kustomization.yaml
└── plugin-barman-cloud/       # Barman Cloud backup plugin
    ├── helmrelease.yaml
    └── kustomization.yaml
```

**Note:** PgAdmin is a separate app in `../pgadmin/` and currently uses CPGO's PGAdmin CRD.

## Deployment Order

1. **cloudnative-pg** - Operator
   - Version: 0.26.1
   - Automatically creates and manages CRDs
   - Includes PodMonitor for Prometheus
   - Includes Grafana dashboard
   - Resources: 100m CPU, 128-256Mi RAM

2. **plugin-barman-cloud** - Backup plugin (depends on operator)
   - Version: 0.2.0
   - Enables S3-compatible backups with Barman
   - Adds `ObjectStore` CRD

## Creating PostgreSQL Clusters

Clusters should be deployed in their respective app namespaces, not in the `database` namespace.

### Example: Deploy PostgreSQL for Miniflux

```yaml
# In kubernetes/apps/self-hosted/miniflux/ks.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: miniflux-db
  namespace: flux-system
spec:
  targetNamespace: self-hosted
  path: ./kubernetes/apps/self-hosted/miniflux
  dependsOn:
    - name: cloudnative-pg
      namespace: database
    - name: plugin-barman-cloud
      namespace: database
  postBuild:
    substitute:
      APP: miniflux
      CNPG_SIZE: 2Gi
      CNPG_BACKUP_SCHEDULE: '@daily'
  components:
    - ../../../../components/cnpg/backup  # With backups
```

See `/kubernetes/components/cnpg/README.md` for all available variables and components.

## Monitoring

### Prometheus Metrics

The operator exposes metrics at `:8080/metrics`:
- `cnpg_backends_*` - Backend connection stats
- `cnpg_pg_*` - PostgreSQL internal metrics
- `cnpg_collector_*` - Collector performance

### Grafana Dashboard

Automatically deployed with the operator. Check Grafana for "CloudNativePG" dashboard.

### Alerts

See `app/prometheusrule.yaml` for configured alerts:
- **LongRunningTransaction** - Query taking > 5 minutes
- **BackendsWaiting** - Backend waiting > 5 minutes
- **PGDatabase** - Transaction ID age warning
- **PGReplication** - Standby lag > 500s

## Backup Strategy

All production clusters should use the `backup` component:

```yaml
components:
  - ../../../../components/cnpg/backup
```

This enables:
- **Daily full backups** (configurable via `CNPG_BACKUP_SCHEDULE`)
- **Continuous WAL archiving** to S3
- **Point-in-Time Recovery (PITR)** capability
- **7-day retention** (configurable in ObjectStore)
- **bzip2 compression** + **AES256 encryption**

## Resources

- **Operator resources:** 100m CPU, 128-256Mi RAM
- **Cluster resources:** See `/docs/cnpg-resource-configs.yaml`
- **Components:** See `/kubernetes/components/cnpg/README.md`

## Migration from CPGO

See `/docs/postgres-cpgo-to-cnpg-analysis.md` for:
- Detailed analysis of current clusters
- Migration strategy
- Resource recommendations
- Backup comparison

## References

- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)
- [Barman Cloud Plugin](https://cloudnative-pg.io/plugin-barman-cloud/)
- [GitHub Repository](https://github.com/cloudnative-pg/cloudnative-pg)
