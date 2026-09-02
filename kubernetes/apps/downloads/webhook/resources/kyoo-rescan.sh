#!/usr/bin/env bash
set -euo pipefail

# Triggered by sonarr-anime/radarr-anime on import/rename/delete. Kyoo's
# scanner relies on inotify, which never fires for changes made by other NFS
# clients — so we ask it for a full rescan (cheap: diffs against its DB).
: "${KYOO_SCANNER_APIKEY:?Kyoo scanner apikey required}"

PAYLOAD=${1:-}
EVENT=$(jq -r '.eventType // empty' <<<"${PAYLOAD}" 2>/dev/null || true)

# Ignore health/test chatter
[[ "${EVENT}" == "Test" || "${EVENT}" == "HealthIssue" || "${EVENT}" == "HealthRestored" ]] && exit 0

echo "[DEBUG] Kyoo rescan triggered by event: ${EVENT:-unknown}"
curl -fsS --max-time 30 -X PUT \
    -H "X-API-KEY: ${KYOO_SCANNER_APIKEY}" \
    http://kyoo-traefik.media.svc.cluster.local/scanner/scan
