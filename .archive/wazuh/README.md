# Wazuh (archived 2026-11-10)

Retired as overkill for a homelab: ~5 GiB RAM (indexer alone 4.6 GiB) and
2x50Gi Ceph, while Falco, trivy-operator, CrowdSec and the vmalert LogsQL
rules already cover detection.

## Contents

- `ks.yaml`, `app/` — the `kubernetes/platform/security/wazuh` Flux app
  (morgoved/wazuh-helm, Kanidm OIDC on the dashboard, RBAC sync CronJob)
- `docker/aincrad-agent`, `docker/bifrost-agent` — doco-cd agent stacks
- `ansible/` — native bifrost agent tasks + ossec.conf template
- `vmalert-rules.yaml` — `wazuh` LogsQL group (alerts came in via wazuh-csyslogd)
- `falco-exception.yaml` — FIM exception for the manager reading /etc/shadow

## Wiring removed elsewhere (restore on revival)

- towonel-agent TCP services `wazuh-agents` (1514) / `wazuh-enrollment` (1515)
  and the bifrost hub's `127.0.0.1:1514-1515` port binds
- `WAZUH_REGISTRATION_PASSWORD` in `docker/bifrost/.doco-cd.yaml`
- Kanidm OAuth2 client `wazuh` (ConfigMap `kanidm-provision-oauth2-security`)
- Renovate `wazuh` group and agent changelog source
- nix-config `modules/services/wazuh-agent.nix` (ragnarok)
- mikrotik-terraform `st_guest_monitored` + `allow-guest-to-wazuh`
- Infisical `/kubernetes/security/wazuh`, `/vps/aincrad/WAZUH_AUTHD_PASS`
