# Kanidm

Identity provider (Authentik replacement). Deployment pattern based on bjw-s / eleboucher,
adapted to home-ops (Infisical, Envoy Gateway, Volsync, schemas.vzkn.eu).

- Host: `idm.vzkn.eu` (envoy-external) — runs in parallel with Authentik (`sso.vzkn.eu`) during migration.
- TLS: Kanidm terminates its own TLS (mandatory). cert-manager `idm-vzkn-eu` → secret mounted at `/certs`.
  `BackendTLSPolicy` makes Envoy re-encrypt to the HTTPS backend.
- Storage: `/data` PVC `kanidm` (ceph-block) via `components/volsync`.
- Provisioning: `m00nwtchr/kanidm-provision` sidecar (declarative oauth2/groups from ConfigMaps,
  writes client secrets back to k8s Secrets). **Starts at `replicas: 0`** until the token exists.

## Bootstrap (one-time, after first deploy)

### 1. Recover built-in accounts
```bash
kubectl exec -n security -it statefulset/kanidm -c app -- kanidmd recover-account admin
kubectl exec -n security -it statefulset/kanidm -c app -- kanidmd recover-account idm_admin
```
Each command prints a **`new_password`** — that's a password to LOG IN with, NOT a `/ui/reset`
token. Use it directly:
```bash
kanidm login --name idm_admin --url https://idm.vzkn.eu   # paste the new_password
```
(`/ui/reset` only accepts credential-reset tokens from `kanidm person credential
create-reset-token` — used later for your own person account / passkey, not for bootstrap.)

### 2. Create the provision service account + token
The `kanidm` CLI needs a server URI on every command. Set it once (env or `~/.config/kanidm`
with `uri = "https://idm.vzkn.eu"`); the cached login token persists, so no re-auth needed:
```bash
export KANIDM_URL="https://idm.vzkn.eu"
kanidm service-account create kanidm-provision "Kanidm Provision" idm_admins -D idm_admin
kanidm group add-members idm_admins kanidm-provision -D idm_admin
kanidm service-account api-token generate --readwrite kanidm-provision provision-token -D idm_admin
```
Push the printed token to Infisical:
- Path: `/kubernetes/security/kanidm`
- Key: `KANIDM_PROVISION_TOKEN`

Then bump the provision controller `replicas: 0 → 1` in `helmrelease.yaml` and reconcile.

### 3. Core groups (mirrors terraform/authentik hierarchy)
```bash
for g in pending users admins ff household; do
  kanidm group create "$g" -D idm_admin
done
kanidm group add-members users <you> -D idm_admin
kanidm group add-members admins <you> -D idm_admin
```

### 4. Per-app OAuth2 client (example: Grafana)
```bash
kanidm system oauth2 create grafana 'Grafana' https://grafana.vzkn.eu -D idm_admin
kanidm system oauth2 add-redirect-url grafana https://grafana.vzkn.eu/login/generic_oauth -D idm_admin
kanidm system oauth2 update-scope-map grafana users openid email profile groups -D idm_admin
kanidm system oauth2 update-claim-map-join grafana grafana_role array -D idm_admin
kanidm system oauth2 update-claim-map grafana grafana_role admin Admin -D idm_admin
kanidm system oauth2 show-basic-secret grafana -D idm_admin   # → Infisical
```

Once the provision sidecar is running, manage clients/groups declaratively via ConfigMaps
labelled `kanidm_config=1` instead of the CLI (see oddlama/kanidm-provision state schema).

## Migration tracking
Full plan + per-app mapping: `.private/kanidm-migration/PLAN.md`.

## Deluxe deploy — what's included beyond the minimal pattern
- **Full `server.toml`** (ConfigMap → `/data/server.toml`, the container's baked default path; env
  still applies on top as a safety net). Enables what env can't:
  - `[online_backup]` — SQLite-consistent dumps to `/data/backups` every 6h, keep 14 (volsync also
    snapshots the PVC hourly → belt-and-suspenders for an IdP).
  - `[http_client_address_info]` — trusts `X-Forwarded-For` from the pod CIDR so audit/rate-limit
    see the real client IP, not the Envoy pod IP.
- **`priorityClassName: system-cluster-critical`** — protects the IdP from eviction under memory
  pressure (cluster has OOM-cascade history).
- **Control-plane placement** (nodeSelector + tolerations) — identity survives a worker failure.
  RBD CSI nodeplugin runs on CP nodes, so the ceph-block PVC mounts there.
- **CiliumNetworkPolicy** (`networkpolicy.yaml`) — :8443 (public-facing web/OIDC) open to any
  in-cluster source (gateway hairpin, OIDC app backends, probes); :3636 (LDAP, sensitive) locked to
  `communication`/`media` only. Egress open (SMTP relay, DNS, k8s API for provision).
- **Declarative provisioning** (`provisioning/*.yaml`, label `kanidm_config=1`) — groups + 12 OIDC
  clients. The sidecar writes secret `kanidm-<name>-oidc` (keys `client-id`/`client-secret`) per
  client. **Target namespace is ConfigMap-level** (`data.targetNamespace`), NOT per-client — the
  sidecar overwrites any per-client value. So `oauth2.yaml` is split into one ConfigMap per
  namespace. Apps are rewired to these secrets in Phase 2.

## Notes
- RBAC (secrets create/patch, configmaps read) is scoped to the `provision` ServiceAccount only;
  the internet-facing server pod uses a separate powerless `kanidm` SA.
- `/status` is a public unauthenticated health endpoint (used by the probes).
- OIDC redirect URLs in `provisioning/oauth2.yaml` come from the Authentik era — verify each against
  the app's real callback when you flip it from Authentik to Kanidm in Phase 2. `forgejo` assumes the
  Forgejo auth source is renamed to `kanidm`. `unraid` is external (aincrad NAS, no k8s secret).
  Nextcloud + sparkyfitness were dropped (never deployed) — `nextcloudAdmin` group also removed.
- Once the provision sidecar runs, manage groups/clients via the ConfigMaps — not the CLI.
- No OTEL: Kanidm has no Prometheus `/metrics`; OTLP (`otel_grpc_url`) needs a collector we don't run yet.
