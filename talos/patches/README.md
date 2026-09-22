# Talos config patches

Layered onto `../machineconfig.yaml.j2` by `scripts/render-machine-config.sh`,
in this order, and merged by `talosctl machineconfig patch`:

| Layer | Applies to |
| --- | --- |
| `global/` | every node |
| `controller/` | control plane only |
| `worker/` | workers only |
| `../nodes/<role>/<node>.yaml.j2` | one node |

A node's role comes from which `nodes/` subdirectory holds its file, not from
anything written inside it.

## File naming

Two conventions, and the prefix is the whole signal:

- **`machine-*.yaml`** — a strategic-merge patch against the legacy `v1alpha1`
  document. Every one of these is a migration candidate; see the table below.
- **anything else** — a Talos multi-document config, named after the document
  kind it carries (`resolver.yaml` holds `ResolverConfig`). These are what Talos
  now calls the "small, focused configuration fragments" model, and they are
  where new configuration should go.

`.yaml.j2` is used only where a file genuinely needs templating — the base
(secrets from Infisical, machine type) and the per-node files (hostname, install
disk, NIC layout). Patches are static, so they stay plain `.yaml`.

JSON6902 is not an option anywhere here: `talosctl machineconfig patch` rejects
it whenever the config is multi-document, which this one always is.

## Migration to Talos 1.14

1.14 moves nearly the whole `v1alpha1` surface into typed documents. Deprecated
fields keep working, but **a deprecated field and its replacement document are
mutually exclusive — a config setting both is rejected**, so each row has to
move in one go rather than field by field.

| File | Replacement document | Status |
| --- | --- | --- |
| `global/machine-sysctls.yaml` | `SysctlConfig` | waiting on 1.14 |
| `global/machine-files.yaml` | `EtcFileConfig` (nfsmount.conf) + `CRICustomizationConfig` (containerd) | waiting on 1.14 |
| `global/machine-kubelet.yaml` | `KubeletConfig` | waiting on 1.14 |
| `global/machine-openebs.yaml` | `KubeletConfig` (extraMounts) | waiting on 1.14 |
| `controller/cluster.yaml` | `KubeAPIServerConfig`, `KubeAuditPolicyConfig`, `KubeControllerManagerConfig`, `KubeSchedulerConfig`, `KubeProxyConfig`, `KubeCoreDNSConfig`, etcd | waiting on 1.14, split into several files |
| `controller/machine-features.yaml` | not yet mapped | confirm against 1.14 docs |
| `*/machine-nodelabels.yaml` | `KubeNodeConfig` | confirm against 1.14 docs |

Already converted, on 1.13:

| Was | Now |
| --- | --- |
| `machine.registries.mirrors` | `registry-mirrors.yaml` — 16 × `RegistryMirrorConfig` |
| `machine.network.nameservers` + `disableSearchDomain` | `resolver.yaml` — `ResolverConfig` |
| `machine.time` | `timesync.yaml` — `TimeSyncConfig` |

Check what the installed `talosctl` actually registers before converting
anything — a kind the running Talos does not know is rejected outright:

```bash
talosctl docs /tmp/talosdocs --config && grep -rhoE '^kind: .*' /tmp/talosdocs | sort -u
```
