#!/usr/bin/env bash
set -euo pipefail

# Incoming arguments
PAYLOAD=${1:-}

# Required environment variables
: "${APPRISE_KRR_PUSHOVER_URL:?Pushover URL required}"

echo "[DEBUG] KRR Payload received"

function notify() {
    local scans total critical warning ok

    # Parse KRR JSON output
    scans=$(echo "${PAYLOAD}" | jq -r '.scans // []')
    total=$(echo "${scans}" | jq -r 'length')

    # Count by severity (KRR uses severity field in recommendations)
    critical=$(echo "${scans}" | jq -r '[.[] | select(.recommended.requests.cpu.severity == "CRITICAL" or .recommended.requests.memory.severity == "CRITICAL" or .recommended.limits.cpu.severity == "CRITICAL" or .recommended.limits.memory.severity == "CRITICAL")] | length')
    warning=$(echo "${scans}" | jq -r '[.[] | select(.recommended.requests.cpu.severity == "WARNING" or .recommended.requests.memory.severity == "WARNING" or .recommended.limits.cpu.severity == "WARNING" or .recommended.limits.memory.severity == "WARNING")] | length')
    ok=$((total - critical - warning))

    # Build message
    printf -v PUSHOVER_TITLE "KRR Resource Report"

    if [[ "${critical}" -gt 0 ]]; then
        printf -v PUSHOVER_MESSAGE "<b>Scanned %s workloads</b>\n\n<font color=\"#ff0000\">Critical: %s</font>\n<font color=\"#ffa500\">Warning: %s</font>\nOK: %s\n\n<small>Run kubectl logs for details</small>" \
            "${total}" "${critical}" "${warning}" "${ok}"
        printf -v PUSHOVER_PRIORITY "high"
    elif [[ "${warning}" -gt 0 ]]; then
        printf -v PUSHOVER_MESSAGE "<b>Scanned %s workloads</b>\n\n<font color=\"#ffa500\">Warning: %s</font>\nOK: %s\n\n<small>Run kubectl logs for details</small>" \
            "${total}" "${warning}" "${ok}"
        printf -v PUSHOVER_PRIORITY "normal"
    else
        printf -v PUSHOVER_MESSAGE "<b>Scanned %s workloads</b>\n\nAll resources are properly sized!" \
            "${total}"
        printf -v PUSHOVER_PRIORITY "low"
    fi

    apprise -vv --title "${PUSHOVER_TITLE}" --body "${PUSHOVER_MESSAGE}" --input-format html \
        "${APPRISE_KRR_PUSHOVER_URL}?priority=${PUSHOVER_PRIORITY}&format=html"
}

function main() {
    notify
}

main "$@"
