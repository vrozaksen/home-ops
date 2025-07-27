#!/usr/bin/env bash
set -Eeuo pipefail

function notify() {
    # Parse Discord webhook payload from TQM
    # TQM sends Discord webhook format, so we need to extract the info

    # Read JSON payload from stdin
    payload=$(cat)

    # Try to extract content, fallback to embed description
    content=$(echo "$payload" | jq -r '.content // empty')
    title=$(echo "$payload" | jq -r '.embeds[0].title // "TQM Notification"')
    description=$(echo "$payload" | jq -r '.embeds[0].description // "No description"')

    # Clean up Discord markdown and format for Pushover
    clean_description=$(echo "$description" | sed 's/\*\*//g' | sed 's/\*//g' | sed 's/__//g')

    # Extract client info from footer if available
    client_info=$(echo "$payload" | jq -r '.embeds[0].footer.text // ""')

    # Build Pushover message
    if [[ -n "$content" && "$content" != "null" ]]; then
        pushover_body="$content"
    else
        pushover_body="$clean_description"
    fi

    # Add fields if they exist
    fields=$(echo "$payload" | jq -c '.embeds[0].fields // empty')
    if [[ -n "$fields" && "$fields" != "null" && "$fields" != "[]" ]]; then
        # Format fields as a list
        fields_text=""
        field_count=$(echo "$fields" | jq 'length')
        for ((i=0; i<field_count; i++)); do
            name=$(echo "$fields" | jq -r ".[$i].name")
            value=$(echo "$fields" | jq -r ".[$i].value")
            inline=$(echo "$fields" | jq -r ".[$i].inline")
            if [[ "$inline" == "true" ]]; then
                fields_text+="<b>$name:</b> $value  "
            else
                fields_text+="<b>$name:</b> $value\n"
            fi
        done
        pushover_body+="\n\n$fields_text"
    fi

    if [[ -n "${client_info}" ]]; then
        printf -v PUSHOVER_MESSAGE "%s\n\n<small>%s</small>" "$pushover_body" "${client_info}"
    else
        printf -v PUSHOVER_MESSAGE "%s" "$pushover_body"
    fi

    # Fallback if the message is empty
    if [[ -z "$PUSHOVER_MESSAGE" ]]; then
        PUSHOVER_MESSAGE="No details"
    fi

    printf -v PUSHOVER_TITLE "%s" "${title}"
    printf -v PUSHOVER_URL "%s" "${TQM_APPLICATION_URL:-http://qbittorrent.downloads.svc.cluster.local}"
    printf -v PUSHOVER_URL_TITLE "View qBittorrent"
    printf -v PUSHOVER_PRIORITY "normal"

    apprise -vv --title "${PUSHOVER_TITLE}" --body "${PUSHOVER_MESSAGE}" --input-format html \
        "${TQM_PUSHOVER_URL}?url=${PUSHOVER_URL}&url_title=${PUSHOVER_URL_TITLE}&priority=${PUSHOVER_PRIORITY}&format=html"
}

function main() {
    notify
}

main "$@"
