# Tetragon eBPF Security Observability

Tetragon provides eBPF-based **runtime security observability** complementing Trivy's static vulnerability scanning.

## What Tetragon Monitors

- **Process Events**: Execution, termination, capabilities via eBPF kprobes
- **File Access**: Sensitive files (/etc/shadow, SSH keys, kubelet configs)
- **Network Activity**: Suspicious C2 port connections
- **Privilege Escalation**: CAP_SYS_ADMIN shells, nsenter, container escapes
- **Threats**: Crypto miners, curl|bash, malicious binaries

## TracingPolicies (8 Active)

1. **sensitive-files** - /etc/shadow, passwd, sudoers, kubelet, kubernetes
2. **privileged-execution** - Shells with CAP_SYS_ADMIN/PTRACE/MODULE
3. **suspicious-network** - C2 ports (4444, 31337, 8080, 12345)
4. **crypto-mining-detection** - xmrig, ethminer, curl|bash
5. **ssh-activity** - SSH/SCP/SFTP executions
6. **package-management** - apt/yum/pip/npm installs
7. **container-escape-attempts** - nsenter, docker socket, crictl
8. **kubectl-exec** - kubectl command tracking

## Prometheus Metrics (What You See)

### Event Metrics (Aggregated Counts Only)
```
tetragon_events_total{type,namespace,workload,pod,binary}
tetragon_policy_events_total{policy,hook,namespace,workload,pod}
tetragon_syscalls_total{syscall,namespace,workload,pod,binary}
```

### Health Metrics
```
tetragon_tracingpolicy_loaded{state} - Loaded policies
tetragon_tracingpolicy_kernel_memory_bytes - Memory usage
tetragon_bpf_missed_events_total - Lost events
tetragon_process_cache_size - Cache utilization
```

## What Metrics DON'T Show

Prometheus metrics are **aggregated counters** - you won't see:
- ❌ Command line arguments
- ❌ File paths accessed
- ❌ Network IPs/ports details
- ❌ User/UID information
- ❌ Process ancestry trees

## Getting Detailed Events

### Real-time Streaming (CLI)
```bash
kubectl exec -n security ds/tetragon -c tetragon -- tetra getevents -o compact
```

### Export to Loki/Elasticsearch
Add Fluent Bit to ship `/var/run/tetragon/tetragon.log` for:
- Full-text search on commands
- Log correlation and forensics
- Long-term retention

Example Loki query:
```logql
{app="tetragon"} |= "PROCESS_EXEC" | json | binary =~ ".*miner.*"
```

## Monitoring Integration

### Prometheus Alerts
- **Critical** (→ Pushover): Sensitive file access, crypto mining, agent down
- **Warning**: Suspicious network, high event rate, policy errors

### Grafana Dashboard
Custom `dashboards/tetragon-overview.json` with:
- Agent health & policy count
- Event rates by type/policy
- Missed events tracking
- Kernel memory per policy

### Gatus Health Checks
- tetragon-agent-health (gRPC port 6789)
- tetragon-process-events (event rate)
- tetragon-policy-loaded (policy status)

## Configuration Highlights

- **Inline OCIRepository**: oci://ghcr.io/cilium/charts/tetragon:1.6.0
- **Cilium Integration**: enableCiliumAPI: true
- **Host Network**: Required for process visibility
- **Export Allowlist**: PROCESS_EXEC, PROCESS_EXIT, PROCESS_KPROBE, PROCESS_TRACEPOINT
- **Redaction**: password, token, api_key, secret, Bearer
- **Resources**: Agent 512Mi-2Gi, Operator 64Mi-128Mi

## Talos Compatibility

✅ **Verified** on Talos v1.11.0, Kernel 6.12.43
- BTF enabled (CONFIG_DEBUG_INFO_BTF=y)
- hostProcPath: /proc (Talos-specific)

## References

- [Tetragon Metrics Docs](https://tetragon.io/docs/reference/metrics/)
- [TracingPolicy Library](https://github.com/cilium/tetragon/tree/main/examples/tracingpolicy)
- [xunholy's Config](https://github.com/xunholy/k8s-gitops/blob/main/kubernetes/apps/base/kube-system/tetragon/app/values.yaml)
