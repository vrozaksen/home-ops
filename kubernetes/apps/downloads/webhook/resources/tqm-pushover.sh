#!/usr/bin/env bash
set -Eeuo pipefail

function notify() {
    # Parse Discord webhook payload from TQM
    # TQM sends Discord webhook format, so we need to extract the info

    # Read JSON payload from first argument
    payload="$1"

    # Merge all embeds into a single message
    title=$(echo "$payload" | jq -r '.embeds[0].title // "TQM Notification"')
    embed_count=$(echo "$payload" | jq '.embeds | length')
    message_body=""
    for ((i=0; i<embed_count; i++)); do
        description=$(echo "$payload" | jq -r ".embeds[$i].description // \"\"")
        clean_description=$(echo "$description" | sed 's/\*\*//g' | sed 's/\*//g' | sed 's/__//g')
        footer=$(echo "$payload" | jq -r ".embeds[$i].footer.text // \"\"")
        if [[ -n "$clean_description" ]]; then
            message_body+="$clean_description"
        fi
        if [[ -n "$footer" ]]; then
            message_body+="<br><small>$footer</small>"
        fi
        # Add HTML line break between embeds except after last
        if (( i < embed_count - 1 )); then
            message_body+="<br><br>"
        fi
    done
    # Send message in batches of 1024 chars
    msg_len=${#message_body}
    batch_size=1024
    printf -v PUSHOVER_TITLE "%s" "${title}"
    printf -v PUSHOVER_URL "%s" "${TQM_APPLICATION_URL:-http://qbittorrent.downloads.svc.cluster.local}"
    printf -v PUSHOVER_URL_TITLE "%s" "View qBittorrent"
    for ((offset=0; offset<msg_len; offset+=batch_size)); do
        batch_msg="${message_body:offset:batch_size}"
        printf -v PUSHOVER_MESSAGE "%s" "$batch_msg"
        apprise -vv --title "${PUSHOVER_TITLE}" --body "${PUSHOVER_MESSAGE}" --input-format html \
            "${TQM_PUSHOVER_URL}?url=${PUSHOVER_URL}&url_title=${PUSHOVER_URL_TITLE}&priority=low&format=html"
    done

    # Always set Pushover priority to 'low'
    printf -v PUSHOVER_PRIORITY "low"

    apprise -vv --title "${PUSHOVER_TITLE}" --body "${PUSHOVER_MESSAGE}" --input-format html \
        "${TQM_PUSHOVER_URL}?url=${PUSHOVER_URL}&url_title=${PUSHOVER_URL_TITLE}&priority=${PUSHOVER_PRIORITY}&format=html"
}

function main() {
    notify "$@"
}

main "$@"
