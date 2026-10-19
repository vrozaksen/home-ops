# Talos ingress firewall: design and staged rollout (VZK-193)

Status: **design only, nothing applied.** No file under `talos/patches/` changes
in this PR; the candidate documents live here until the owner approves a stage.

Talos 1.14.1 (pinned in `kubernetes/core/system-upgrade/tuppr/upgrades/talosupgrade.yaml`)
registers `NetworkDefaultActionConfig` and `NetworkRuleConfig`
([upstream guide](https://docs.siderolabs.com/talos/v1.14/networking/ingress-firewall)).

## How the firewall behaves (from the upstream page)

| Default action | Effect of each `NetworkRuleConfig` | Always allowed |
| --- | --- | --- |
| `accept` (today) | **Drops** the listed ports/protocols from every source outside `ingress` | `lo`, `siderolink`, `kubespan` |
| `block` | **Allows** the listed ports/protocols from `ingress`; everything else inbound is dropped | as above, plus established/related, ICMP (5 pps), traffic between pod/service subnets |

- Rules are nftables `input` hook only. Pod-to-pod and forwarded traffic is not touched.
- IPv6 to a ruled port is dropped unless `::/0` is listed. This cluster is IPv4 only.
- A rule's `except` field carves holes out of `subnet`.
- `talosctl apply-config --mode=try` applies temporarily and reverts on its own.

## What reaches the host in this cluster

Verified from the repo; items marked *check* are not verified live.

| Fact | Source |
| --- | --- |
| Node IPs 10.10.0.15-17 (CP saga/eir/skuld), 10.10.0.21-23 (alfheim/alne/ainias); `10.10.0.0/24` is a flat Servers VLAN that also holds the NAS, the PDU and the LoadBalancer pool | `talos/nodes/*`, `cilium/app/networking.yaml` |
| API endpoint `https://10.10.0.20:6443` is a Cilium LoadBalancer Service with host-network backends (kube-apiserver) | `networking.yaml`, `machineconfig.yaml.j2` |
| Cilium: native routing, kube-proxy replacement, DSR, no VXLAN/Geneve, BGP to the MikroTiks (10.10.0.1/.2), L2 announcements | `cilium/app/helmrelease.yaml` |
| Pod CIDR `10.69.0.0/16`, service CIDR `10.96.0.0/16` | `machineconfig.yaml.j2` |
| Rook-Ceph on host network, both networks `10.10.0.0/24`, msgr2 only | `rook-ceph/cluster/helmrelease.yaml` |
| etcd metrics on `0.0.0.0:2381` | `patches/controller/cluster.yaml` |
| Pods use the host resolver (`forwardKubeDNSToHost: true`) | `patches/global/resolver.yaml` |
| Spegel registry `hostPort 29999` | `spegel/app/helmrelease.yaml` |
| kmsg-bridge listens on UDP 5514 of loopback only | `victoria-logs/kmsg-bridge/helmrelease.yaml` |
| In-cluster Talos API clients: tuppr and the home-ops-runner (`KubeTalosAPIAccessConfig`), plus talos-mcp | `patches/controller/kube-talos-api-access.yaml` |

## Allowed sources per port

`NODES` = the six node `/32`s. `PODS` = `10.69.0.0/16`. `ADMIN` = admin LAN
CIDR(s), **needed from the owner** (not recorded anywhere I could read).
Node `/32`s are used instead of `10.10.0.0/24` so the NAS, PDU and any other
Servers-VLAN host cannot reach the management ports.

| Port | Service | Roles | Allowed sources | Why |
| --- | --- | --- | --- | --- |
| 50000/tcp | apid | all | NODES, PODS, ADMIN | talosctl, tuppr, runner, talos-mcp (pods) |
| 50001/tcp | trustd | CP | NODES | workers fetch certificates |
| 10250/tcp | kubelet | all | NODES, PODS | apiserver logs/exec from CPs, metrics scrapes |
| 2379-2380/tcp | etcd | CP | the 3 CP `/32`s | peer and client traffic |
| 2381/tcp | etcd metrics | CP | NODES, PODS | vmagent scrape |

`PODS` is listed because Cilium does not masquerade pod traffic to cluster node
IPs by default, so an in-cluster client may arrive with its pod IP. *Check*
before Stage 1 with a Hubble flow from tuppr to a node on 50000. If the source
turns out to be the node IP, drop `PODS` from apid and kubelet.

Not restricted in Stage A: 6443 (apiserver; reached from the LAN through
10.10.0.20, authenticated, and the LAN CIDRs are unknown), and every
host-network service of Ceph, Cilium and Spegel.

## Stage A candidate: keep `accept`, restrict only the management ports

Smallest change that closes the audit gap: apid, kubelet, trustd and etcd stop
answering the whole Servers VLAN and beyond. Nothing else changes, so Ceph,
Cilium, DNS and NodePorts are unaffected by construction.

Global (all nodes):

```yaml
---
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: apid-ingress
portSelector:
  ports: [50000]
  protocol: tcp
ingress:
  - {subnet: 10.10.0.15/32}
  - {subnet: 10.10.0.16/32}
  - {subnet: 10.10.0.17/32}
  - {subnet: 10.10.0.21/32}
  - {subnet: 10.10.0.22/32}
  - {subnet: 10.10.0.23/32}
  - {subnet: 10.69.0.0/16}
  - {subnet: <ADMIN_CIDR>}
---
apiVersion: v1alpha1
kind: NetworkRuleConfig
name: kubelet-ingress
portSelector:
  ports: [10250]
  protocol: tcp
ingress:
  - {subnet: 10.10.0.15/32}
  - {subnet: 10.10.0.16/32}
  - {subnet: 10.10.0.17/32}
  - {subnet: 10.10.0.21/32}
  - {subnet: 10.10.0.22/32}
  - {subnet: 10.10.0.23/32}
  - {subnet: 10.69.0.0/16}
```

Control plane only (`talos/patches/controller/`): `trustd-ingress` (50001, NODES),
`etcd-ingress` (2379-2380, the three CP `/32`s) and `etcd-metrics-ingress`
(2381, NODES + PODS), same document shape.

Validation done for this design: the five documents above (with a dummy admin
CIDR) decode under `talosctl validate --mode metal` from talosctl 1.14.4; the
only errors are the missing CA and cluster sections of the stub base config.
A rule with `protocol: sctp` is rejected, so the validator really parses them.

## Stage B (optional, later): `ingress: block`

Adds `NetworkDefaultActionConfig` with `ingress: block` plus an allow rule for
every other host listener. This is where the "cut off the cluster" risk lives.
Candidates, all *check* against `talosctl netstat -l` and Hubble before use:

| Listener | Needs | Source |
| --- | --- | --- |
| Kubernetes API 6443 (CP) | allow from LAN, nodes, pods | LB 10.10.0.20 backend is host-network |
| Ceph mon/mgr/OSD (3300, 6800-7300) | allow from `10.10.0.0/24` | host-network Ceph, krbd clients on every node |
| Cilium health/hubble/metrics (4240, 4244, 9962-9965, 10256) | allow from NODES, PODS, router for 10256 | port numbers are chart defaults, not verified live |
| Spegel 29999, router port | allow from NODES | peer image pulls |
| BGP 179 from 10.10.0.1/.2 | allow from the two routers | MikroTik is configured `listen=yes` |
| Pod DNS to the host resolver | allow udp+tcp 53 from PODS | `forwardKubeDNSToHost: true`; a miss is a cluster-wide DNS outage |
| DHCP on workers (bond0 DHCPv4) | allow udp 68 from 10.10.0.1/32 | lease renewal after block *check* |
| NodePorts (e.g. 30893) | probably handled in Cilium BPF before nftables | *check* empirically |

Recommendation: ship Stage A, soak it, and treat Stage B as a separate decision.
It buys little over Stage A (the management ports are already restricted) and
carries all the outage risk.

## Rollout

Every apply is run by the owner; each step needs an explicit yes on VZK-193.
Order within a stage: one worker canary, remaining workers, then control planes
one at a time. Use `--mode=no-reboot` (no `_down`/`_up`, no drain, no kopiur
suspend).

| Step | Action | Gate before the next step |
| --- | --- | --- |
| 0 | Read-only preflight: `talosctl get nftableschain` baseline per node; Hubble flows to node IPs on 50000/10250/2379-2381 over a few days to confirm the real source set; owner supplies `ADMIN` CIDRs | source list reconciled with the flows |
| 1 | Add the patch files on a branch; owner renders and dry-runs a worker and a CP (`just talos render-config <node>`, `talosctl apply-config --dry-run`). The diff must contain only the new documents | diff is exactly the intended documents |
| 2 | Canary worker with `apply-config --mode=try --timeout 10m` | checks below pass from the admin host and from a pod; wait out the revert and re-confirm access |
| 3 | Same canary with `--mode=no-reboot` | checks pass after 24 h |
| 4 | Other two workers, then CPs `saga`, `eir`, `skuld` one at a time | `talosctl etcd status` healthy and three members after each CP |
| 5 | Soak 7 days, then decide on Stage B | owner decision |

Checks after each node (all read-only):

- `talosctl -n <node> version` from the admin host (apid from ADMIN).
- `talosctl -n <node> get nftableschain -o yaml` lists the new ingress chain and no extra drops.
- tuppr and talos-mcp can still reach apid (pod source); Prometheus targets for kubelet and etcd stay up.
- From a host outside the allowed set (a Servers-VLAN host that is not a node): `nc -zv <node> 50000` and `10250` time out.
- `kubectl get nodes`, `ceph status` unchanged, no new alerts.

## Rollback and lock-out

- `--mode=try` reverts by itself if the new config breaks access.
- Permanent revert: remove the documents, `talosctl apply-config --mode=no-reboot` from any still-allowed source.
- Break-glass if apid becomes unreachable from the admin host: the pod CIDR is allowed, so
  an in-cluster client (talos-mcp, or a pod with a talosconfig) can push the revert. If
  cluster networking is also down, recovery is console access plus reinstall, which is
  why nothing goes to a control plane before a worker canary has soaked.
- A bad etcd rule on a CP can drop quorum. The CP step therefore goes one node at a time with an etcd check in between.

## Open questions for the owner

1. Admin CIDR(s) that run `talosctl`/`kubectl` today (workstation VLAN, VPN). Anything missing is locked out of apid.
2. Is Stage A alone acceptable as the delivered scope, with Stage B deferred?
3. Canary node preference (default: `alne`).

## Out of scope

Cilium host firewall (`CiliumClusterwideNetworkPolicy` on nodes) would give
pod-identity-level rules, but it is Cilium networking and excluded for this issue.
