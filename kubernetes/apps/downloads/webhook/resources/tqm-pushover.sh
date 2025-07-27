#!/usr/bin/env bash
set -Eeuo pipefail

function notify() {
    # Parse Discord webhook payload from TQM
    # TQM sends Discord webhook format, so we need to extract the info

    # Read JSON payload from stdin
    payload=$(cat)

    # Extract title, description, and footer
    title=$(echo "$payload" | jq -r '.embeds[0].title // "TQM Notification"')
    description=$(echo "$payload" | jq -r '.embeds[0].description // "No description"')
    footer=$(echo "$payload" | jq -r '.embeds[0].footer.text // ""')

    # Clean up Discord markdown in description
    clean_description=$(echo "$description" | sed 's/\*\*//g' | sed 's/\*//g' | sed 's/__//g')

    # Build Pushover message: description, then footer if present
    if [[ -n "$footer" ]]; then
        printf -v PUSHOVER_MESSAGE "%s\n\n<small>%s</small>" "$clean_description" "$footer"
    else
        printf -v PUSHOVER_MESSAGE "%s" "$clean_description"
    fi

    printf -v PUSHOVER_TITLE "%s" "${title}"
    printf -v PUSHOVER_URL "%s" "${TQM_APPLICATION_URL:-http://qbittorrent.downloads.svc.cluster.local}"
    printf -v PUSHOVER_URL_TITLE "View qBittorrent"

    # Always set Pushover priority to 'low'
    printf -v PUSHOVER_PRIORITY "low"

    apprise -vv --title "${PUSHOVER_TITLE}" --body "${PUSHOVER_MESSAGE}" --input-format html \
        "${TQM_PUSHOVER_URL}?url=${PUSHOVER_URL}&url_title=${PUSHOVER_URL_TITLE}&priority=${PUSHOVER_PRIORITY}&format=html"
}

function main() {
    notify
}

main "$@"
