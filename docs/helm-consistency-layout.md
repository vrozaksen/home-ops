# HelmRelease Consistency Layout for app-template

This document defines the standard order and structure for HelmRelease files using the `app-template` chart to ensure consistency across all applications.

## Recommended Order

### 1. **controllers**

The core application definition with the following order:

#### Controller-level (e.g., `controllers.appname`):

- **replicas** - Number of pod replicas
- **type** - Controller type (deployment, daemonset, statefulset)
- **strategy** - Deployment strategy (RollingUpdate, Recreate)
- **forceRename** - Force rename of controller (optional)
- **annotations** - Controller annotations (e.g., reloader)

#### Container-level (e.g., `controllers.appname.containers.app`):

- **image** - Container image configuration
  - `repository`
  - `tag`
  - `pullPolicy`
- **command** - Container command override (if needed)
- **args** - Container arguments (if needed)
- **env** - Explicit environment variables
- **envFrom** - Environment variables from secrets/configmaps
- **probes** - Health check configuration
  - `liveness`
  - `readiness`
  - `startup` (if needed)
- **securityContext** - Container-level security settings
- **resources** - CPU/memory requests and limits
  - `requests`
  - `limits`

### 2. **defaultPodOptions**

Pod-level configurations (use this instead of deprecated `pod:` section):

- **securityContext** - Pod-level security settings
- **nodeSelector** - Node selection constraints
- **tolerations** - Pod tolerations
- **affinity** - Pod affinity rules
- **hostNetwork** - Host networking (rarely needed)
- **hostIPC** - Host IPC access (rarely needed)
- **hostPID** - Host PID access (rarely needed)
- **dnsPolicy** - DNS policy override

### 3. **serviceAccount** (if needed)

Service account configuration

### 4. **configMaps** (if needed)

Application configuration maps

### 5. **secrets** (if needed)

Application secrets

### 6. **service**

Internal networking configuration:

- **controller** - Controller reference (required for multi-controller apps)
- **type** - Service type (ClusterIP, LoadBalancer, NodePort)
- **annotations** - Service annotations (e.g., load balancer IPs)
- **ports** - Service port definitions

### 7. **serviceMonitor** (optional)

Prometheus monitoring configuration

### 8. **ingress** or **route**

External networking configuration:

- **className** - Ingress class
- **hosts** - Host definitions
- **hostnames** - Gateway API hostnames
- **parentRefs** - Gateway API parent references
- **rules** - Gateway API routing rules with backendRefs

### 9. **persistence**

Storage configuration:

- **config** - Application configuration storage
- **data** - Application data storage
- **cache** - Cache storage
- **logs** - Log storage
- **tmpfs** - Temporary filesystem (emptyDir)
- **media** - Media storage (NFS, etc.)

**Mount types in order:**

- `existingClaim` - Existing PVCs
- `type: nfs` - NFS mounts
- `type: emptyDir` - Temporary storage

## Example Structure

```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s-labs/helm-charts/main/charts/other/app-template/schemas/helmrelease-helm-v2.schema.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: &app example-app
spec:
  interval: 1h
  chartRef:
    kind: OCIRepository
    name: app-template
  values:
    controllers:
      example-app:
        replicas: 2
        type: deployment
        strategy: RollingUpdate
        forceRename: example-app
        annotations:
          reloader.stakater.com/auto: "true"
        containers:
          app:
            image:
              repository: ghcr.io/example/app
              tag: 1.0.0@sha256:abcd1234...
            command: ["/app/start.sh"]
            args: ["--config", "/app/config/app.yaml"]
            env:
              TZ: "UTC"
              APP_ENV: production
              PORT: &port 8080
            envFrom:
              - secretRef:
                  name: example-app-secret
            probes:
              liveness: &probes
                enabled: true
                custom: true
                spec:
                  httpGet:
                    path: /health
                    port: *port
                  initialDelaySeconds: 0
                  periodSeconds: 10
                  timeoutSeconds: 1
                  failureThreshold: 3
              readiness: *probes
              startup:
                enabled: true
                custom: true
                spec:
                  httpGet:
                    path: /health
                    port: *port
                  initialDelaySeconds: 0
                  periodSeconds: 5
                  timeoutSeconds: 1
                  failureThreshold: 30
            securityContext:
              allowPrivilegeEscalation: false
              readOnlyRootFilesystem: true
              capabilities: { drop: ["ALL"] }
            resources:
              requests:
                cpu: 100m
                memory: 256Mi
              limits:
                memory: 512Mi
      app2:
        replicas: 1
        strategy: RollingUpdate
        annotations:
          reloader.stakater.com/auto: "true"
        containers:
          app:
            image:
              repository: ghcr.io/example/sidecar
              tag: v1.2.0@sha256:def56789...

            env:
              TZ: "UTC"
              DEBUG: "info"
            securityContext:
              runAsUser: 999
              runAsGroup: 999
              allowPrivilegeEscalation: false
              capabilities: { drop: [ALL] }
            resources:
              requests:
                cpu: 10m
                memory: 256Mi
              limits:
                memory: 512Mi
    defaultPodOptions:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 100
        fsGroup: 100
        fsGroupChangePolicy: OnRootMismatch
      nodeSelector:
        kubernetes.io/arch: amd64
      tolerations:
        - key: "node-role.kubernetes.io/control-plane"
          operator: "Exists"
          effect: "NoSchedule"
    serviceAccount:
      example-app:
        enabled: true
    configMaps:
      config:
        enabled: true
        data:
          app.yaml: |
            server:
              port: 8080
              host: 0.0.0.0
    secrets:
      app:
        enabled: true
        stringData:
          DATABASE_URL: "postgresql://user:pass@host:5432/db"
    service:
      app:
        controller: example-app
        type: ClusterIP
        ports:
          http:
            port: *port
      chrome:
        controller: app2
        ports:
          http:
            port: 3000
      lb:
        controller: example-app
        type: LoadBalancer
        annotations:
          metallb.universe.tf/address-pool: default
        ports:
          http:
            port: *port
    serviceMonitor:
      app:
        endpoints:
          - port: http
            scheme: http
            path: /metrics
            interval: 1m
            scrapeTimeout: 10s
    route:
      app:
        hostnames: ["{{ .Release.Name }}.example.com"]
        parentRefs:
          - name: envoy-external
            namespace: network
        rules:
          - backendRefs:
              - identifier: app
                port: *port
    persistence:
      config:
        existingClaim: "{{ .Release.Name }}"
        globalMounts:
          - path: /app/config
      data:
        type: nfs
        server: storage.example.com
        path: /mnt/data
        globalMounts:
          - path: /app/data
      cache:
        existingClaim: example-app-cache
        globalMounts:
          - path: /app/cache
      tmpfs:
        type: emptyDir
        advancedMounts:
          example-app:
            app:
              - path: /tmp
                subPath: tmp
              - path: /app/logs
                subPath: logs
```

## Rationale

This order follows the logical flow of:

1. **Application Definition** - How the application runs (replicas, strategy, containers)
2. **Security & Resources** - How it's secured and resourced
3. **Supporting Resources** - Service accounts, configs, secrets
4. **Internal Networking** - How it communicates internally
5. **External Networking** - How it's accessed externally
6. **Storage** - Where it stores data

## Migration Checklist

When updating existing HelmRelease files:

- [ ] Move `replicas` and `strategy` to the top of the controller definition
- [ ] Add `type` if using non-default controller type (daemonset, statefulset)
- [ ] Ensure `annotations` come after `strategy`
- [ ] Order container fields: `image` → `command` → `args` → `env` → `envFrom` → `probes` → `securityContext` → `resources`
- [ ] Place `defaultPodOptions` after `controllers`
- [ ] Move `serviceAccount` before `service` if present
- [ ] Add `controller` references to services (especially for multi-controller apps)
- [ ] Ensure `persistence` comes last
- [ ] Verify all sections are in the recommended order
- [ ] **Add TODO comments** for missing recommended configurations
- [ ] **Add ``** to all image configurations

## Notes

- Not all applications will have all sections - this is fine
- The order should be consistent when sections are present
- Use YAML anchors (`&app`, `*app`) for consistency and DRY principles
- Always include the schema comment at the top for validation
- **Never use the deprecated `pod:` section** - use `defaultPodOptions` instead
- **Add TODO comments** for missing but recommended configurations:
  - `# TODO: Add probes for health checks` when probes are missing
  - `# TODO: Add securityContext for container security` when container securityContext is missing
  - `# TODO: Add defaultPodOptions for pod-level security` when defaultPodOptions is missing
  - `# TODO: Add envFrom if secrets are needed` when envFrom might be beneficial
  - `# TODO: Add route for external access if needed` when external access might be needed
  - `# TODO: Add annotations for reloader` when missing reloader annotations
  - `# TODO: Add controller reference to service` when service lacks controller field
- **Strategy considerations:**
  - Use `RollingUpdate` for stateless applications
  - Use `Recreate` for applications that cannot run multiple instances
  - For `StatefulSet` type, strategy is usually `RollingUpdate`
  - For `DaemonSet` type, strategy is usually `RollingUpdate`
- **Multi-controller applications:**
  - Each controller should have its own service with proper `controller` reference
  - Use descriptive controller names (e.g., `app`, `app2`, `database`)
  - Consider resource allocation per controller
