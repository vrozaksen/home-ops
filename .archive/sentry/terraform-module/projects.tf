locals {
  # Default team for new projects. Created here so terraform owns its lifecycle
  # (Sentry auto-creates "#sentry" team for first user; we want explicit one).
  team_slug = "vzkn"

  projects = {
    # ────────────────────────────────────────────────────────────────────
    # sentry-internal: Sentry self-instrumentation + sentry-kubernetes agent
    # (getsentry/sentry-kubernetes, Go impl). K8s events land here.
    # Keep separate from app projects to avoid alert noise mixing.
    #
    # TAG SCHEMA — depends on the WATCHER that produced the event:
    #   watcher=events  (source kubelet/scheduler — real K8s Events:
    #                    Unhealthy, OOMKilled, BackOff, FailedScheduling):
    #                    ENRICHED with `deployment_name` + `node_name`.
    #                    -> fingerprint by {{ tags.deployment_name }}.
    #   watcher=pods    (source x-pod-controller — synthetic container-state
    #                    "Unknown/Error: container X"): FLAT, NO deployment.
    #                    -> these are reboot noise; filter at source via
    #                       SENTRY_K8S_FILTER_OUT_EVENT_SOURCES=x-pod-controller.
    #                       Fallback grouping here = namespace + container_name.
    # Common flat tags both have: namespace, pod_name, container_name, reason.
    # pod_name carries the ReplicaSet hash — NEVER template by it.
    #
    # OWNER TAGS ARE PER-KIND (no single universal "workload" tag, no coalesce
    # in fingerprint rules — a missing tag renders to empty -> events collapse):
    #   deployment_name, helmrelease_name, kustomization_name, job_name,
    #   horizontalpodautoscaler_name, cephcluster_name,
    #   clickhouseinstallation_name, persistentvolume(claim)_name,
    #   service_name, terraform_name, backup_name.
    # Bare pods (e.g. forgejo-runner-task-*) get NO owner tag -> single bucket.
    # Pick the tag matching the event's kind; deployment_name covers the 80%.
    #
    # ORDER MATTERS: Sentry evaluates rules top-down, first match wins.
    # Specific message rules first, broad container catch-alls LAST.
    # ────────────────────────────────────────────────────────────────────
    "sentry-internal" = {
      name     = "Sentry Internal"
      platform = "other"
      # K8s events are inherently transient — a reboot/incident storm goes
      # quiet within hours but leaves hundreds of stale "unresolved" issues
      # forever (fingerprinting groups, it does NOT auto-close). Auto-resolve
      # anything not seen in 48h: clears the backlog and keeps it clean, while
      # genuinely-ongoing crashloops (firing every few min) never go idle long
      # enough to close. 48h survives a multi-day node/Ceph incident.
      resolve_age = 48
      fingerprinting_rules = <<-EOT
        # ── Probe failures (events watcher -> group by deployment) ────────
        message:"*Startup probe failed*"                            -> startup-probe-failed-{{ tags.deployment_name }}
        message:"*Readiness probe failed*"                          -> readiness-probe-failed-{{ tags.deployment_name }}

        # Sentry's OWN liveness probe is `rm /tmp/health.txt` — a worker thread
        # recreates the file each loop; on a slow/idle/restarting worker it
        # isn't there yet and the probe trips. Benign self-noise that fans out
        # across ~30 sentry-* deployments. Collapse ALL into ONE bucket (single
        # root cause, NOT a per-deployment signal). MUST precede the generic
        # Liveness rule below — first match wins.
        message:"*cannot remove '/tmp/health.txt'*"                 -> sentry-liveness-healthfile-race
        message:"*Liveness probe failed*"                           -> liveness-probe-failed-{{ tags.deployment_name }}

        # ── Readiness probe ERRORED (rpc exec into dying container) ───────
        # forgejo-runner / actions-runner ephemeral task pods. Always unique,
        # collapse to ONE bucket. NotFound/Unknown/CONTAINER_EXITED variants.
        message:"*Readiness probe errored and resulted in unknown state*" -> readiness-probe-errored-rpc

        # ── CSI / volume mount (node reboot, driver not yet registered) ───
        # Cluster-wide burst, single root cause -> one bucket each.
        message:"*rook-ceph.rbd.csi.ceph.com not found*"            -> csi-rbd-driver-not-registered
        message:"*CSINode*does not contain driver*rook-ceph.rbd.csi.ceph.com*" -> csi-rbd-driver-not-registered
        message:"*MountVolume.SetUp failed for volume*talos*not registered*" -> projected-volume-not-registered

        # ── Node reboot / drain churn (system-upgrade or manual reboot) ───
        # On reboot the controller evicts EVERY DaemonSet pod on that node and
        # RBD volumes detach/reattach — otherwise fans out to 30+ issues. Node
        # is embedded in the message; the node_name tag is unreliable for
        # controller-emitted events, so collapse each class to ONE static bucket.
        message:"*Found failed daemon pod*will try to kill it*"     -> failed-daemon-pod-on-reboot
        message:"*has been rebooted*boot id*"                       -> node-rebooted
        message:"*Multi-Attach error for volume*"                   -> multi-attach-on-reboot

        # ── Flux / kustomize reconcile churn (not pod events) ─────────────
        message:"*failed early due to stalled resources*"           -> flux-health-check-stalled-{{ tags.kustomization_name }}
        message:"*Operation cannot be fulfilled on persistentvolumeclaims*the object has been modified*" -> pvc-conflict-object-modified

        # ── Generic transient RPC ─────────────────────────────────────────
        message:"*DeadlineExceeded*context deadline exceeded*"      -> context-deadline-exceeded

        # ── HPA external metrics -> group by the HPA that failed ──────────
        message:"*unable to get external metric*probe_success*"     -> external-metric-{{ tags.horizontalpodautoscaler_name }}

        # ── Scheduler / node info ─────────────────────────────────────────
        message:"*Insufficient Node information*allocatable CPU or zone*" -> insufficient-node-information

        # ── Sentry self / ClickHouse operator noise ───────────────────────
        message:"*Update ConfigMap sentry/chi-clickhouse*"          -> clickhouse-configmap-update

        # ── Cilium endpoint restore on node boot ──────────────────────────
        message:"*containerInterface=*subsys=endpoint*"             -> cilium-endpoint-restore

        # ── CrashLoop / OOM / image / scheduling (events watcher) ─────────
        message:"*Back-off pulling image*"                          -> imagepull-backoff-{{ tags.deployment_name }}
        message:"*Back-off restarting failed container*"            -> crashloop-{{ tags.deployment_name }}
        message:"*Job was active longer than specified deadline*"   -> job-deadline-exceeded-{{ tags.namespace }}
        message:"*OOMKilled*"                                       -> oom-killed-{{ tags.deployment_name }}
        message:"*FailedScheduling*"                                -> failed-scheduling-{{ tags.namespace }}

        # ── BROAD CATCH-ALLS — keep dead last ─────────────────────────────
        # Synthetic container-state events (x-pod-controller, NO deployment).
        # Should be filtered at source; if not, fall back to ns+container.
        message:"*Error: container *"                               -> container-error-{{ tags.namespace }}-{{ tags.container_name }}
        message:"*Unknown: container *"                             -> container-unknown-{{ tags.namespace }}-{{ tags.container_name }}
      EOT
    }

    # ────────────────────────────────────────────────────────────────────
    # vroxide: Rust voice client (Slint UI, Win+Linux+macOS) — desktop
    # binary, NOT K8s service. Receives errors + profiling + breadcrumbs
    # per SENTRY.md spec (M02 milestone).
    # ────────────────────────────────────────────────────────────────────
    "vroxide" = {
      name     = "vroxide"
      platform = "rust"
      # No auto-resolve: real desktop panics should persist until triaged,
      # not silently disappear because no new install hit the same bug.
      resolve_age = null
      # No fingerprinting rules — Rust panics already group naturally by
      # type+location.
      fingerprinting_rules = ""
    }
  }
}

resource "sentry_team" "main" {
  organization = data.sentry_organization.main.slug
  name         = "vzkn"
  slug         = local.team_slug
}

resource "sentry_project" "this" {
  for_each = local.projects

  organization         = data.sentry_organization.main.slug
  teams                = [sentry_team.main.slug]
  name                 = each.value.name
  slug                 = each.key
  platform             = each.value.platform
  resolve_age          = each.value.resolve_age
  fingerprinting_rules = each.value.fingerprinting_rules
}

data "sentry_all_keys" "this" {
  for_each = sentry_project.this

  organization = data.sentry_organization.main.slug
  project      = each.value.slug
}

# Spike protection for the vroxide DSN. Unlike the K8s services, vroxide is a
# desktop binary shipped to many installs — a buggy build could flood the
# self-hosted backend. We ship a dedicated rate-limited key as vroxide's DSN
# instead of the unbounded auto-created "Default" key (ADR-0008 BYO-infra).
resource "sentry_key" "vroxide" {
  organization = data.sentry_organization.main.slug
  project      = sentry_project.this["vroxide"].slug
  name         = "vroxide-desktop"

  rate_limit_window = 60  # seconds
  rate_limit_count  = 300 # ≤ 300 events / minute / install
}

locals {
  project_dsns = merge(
    {
      for slug, keys in data.sentry_all_keys.this :
      slug => [for k in keys.keys : k.dsn["public"] if k.name == "Default"][0]
    },
    {
      # vroxide ships the rate-limited key as its DSN (spike protection above).
      vroxide = sentry_key.vroxide.dsn["public"]
    },
  )
}
