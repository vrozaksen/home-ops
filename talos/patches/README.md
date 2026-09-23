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

## The `machine-*` files are waiting on a release that does not exist yet

They move to typed documents (`SysctlConfig`, `EtcFileConfig`, `KubeletConfig`,
`KubeAPIServerConfig`, …) when Talos ships them. **It has not, as of 1.14.1** —
verified against the binary, not the changelog: 1.14.1 registers exactly the
same 44 kinds as 1.13, and every one of those names fails with `not registered`.

Other repos' "migrate to 1.14 multi-document kinds" PRs targeted alpha builds;
talhelper 3.1.17 accepts `FilesystemTrimConfig` only because it pins
`machinery v1.14.0-alpha.2`. Do not plan around a changelog — probe first:

```bash
printf -- '---\napiVersion: v1alpha1\nkind: SysctlConfig\nname: p\n' > /tmp/p.yaml
talosctl validate --config /tmp/p.yaml --mode metal   # "not registered" = absent
```

On 1.14.1 the only deprecation `talosctl validate` actually raises is
`.machine.files`. Everything else still validates clean.

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
