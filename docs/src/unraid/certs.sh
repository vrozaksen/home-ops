#!/bin/bash

# Configuration
BWS_ACCESS_TOKEN="MACHINE_TOKEN"
TLS_CRT_SECRET_ID=""
TLS_KEY_SECRET_ID=""
CADDY_CERT_DIR="/mnt/zfs/appdata/caddy/data/certificates"
CADDY_CONTAINER_NAME="caddy"
CADDY_TEST_URL="https://" # Any valid local URL
NOTIFY="/usr/local/emhttp/plugins/dynamix/scripts/notify"
CURL_TIMEOUT=60

# Log and notify function
log_and_notify() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    if [[ "$2" == "notify" ]]; then
        "$NOTIFY" -e "Caddy Cert Update" -s "$3" -d "$4" -m "$5" -i "${6:-normal}"
    fi
}

# Verify certificate with extended timeout
verify_caddy() {
    log_and_notify "Verifying Caddy endpoint (Timeout: ${CURL_TIMEOUT}s)..."
    if curl --fail --silent --show-error --max-time $CURL_TIMEOUT "$CADDY_TEST_URL" >/dev/null; then
        log_and_notify "Verification successful"
        return 0
    else
        log_and_notify "Verification failed after ${CURL_TIMEOUT} seconds"
        return 1
    fi
}

# Emergency rollback
rollback() {
    log_and_notify "Initiating rollback..." notify "Certificate Rollback" "Reverting certificates" "Restoring previous certificates" "alert"
    mv -f "${FINAL_CRT}.tmp" "$FINAL_CRT"
    mv -f "${FINAL_KEY}.tmp" "$FINAL_KEY"
    docker restart "$CADDY_CONTAINER_NAME"
    exit 1
}

# Clean and extract secret value
clean_secret() {
    local secret="$1"
    # Remove KEY= prefix
    secret="${secret#*=}"
    # Remove surrounding quotes if present
    secret="${secret%\"}"
    secret="${secret#\"}"
    echo "$secret"
}

# Main execution
log_and_notify "Starting certificate update" notify "Certificate Update" "Starting" "Beginning certificate rotation" "normal"

# File paths
TMP_CRT="${CADDY_CERT_DIR}/certificate.crt.tmp"
TMP_KEY="${CADDY_CERT_DIR}/certificate.key.tmp"
FINAL_CRT="${CADDY_CERT_DIR}/wildcard.crt"
FINAL_KEY="${CADDY_CERT_DIR}/wildcard.key"

# Fetch certificate
log_and_notify "Retrieving certificate from Bitwarden..."
CERT_ENV=$(docker run --rm bitwarden/bws secret get "$TLS_CRT_SECRET_ID" --access-token "$BWS_ACCESS_TOKEN" --output env)
CLEAN_CERT=$(clean_secret "$CERT_ENV")
if ! echo "$CLEAN_CERT" | base64 -d > "$TMP_CRT"; then
    log_and_notify "Certificate retrieval failed" notify "Update Failed" "Certificate Error" "Failed to decode certificate" "alert"
    exit 1
fi

# Fetch private key
log_and_notify "Retrieving private key from Bitwarden..."
KEY_ENV=$(docker run --rm bitwarden/bws secret get "$TLS_KEY_SECRET_ID" --access-token "$BWS_ACCESS_TOKEN" --output env)
CLEAN_KEY=$(clean_secret "$KEY_ENV")
if ! echo "$CLEAN_KEY" | base64 -d > "$TMP_KEY"; then
    log_and_notify "Key retrieval failed" notify "Update Failed" "Key Error" "Failed to decode private key" "alert"
    rm -f "$TMP_CRT"
    exit 1
fi

# Backup current certs
log_and_notify "Creating backup of current certificates..."
cp "$FINAL_CRT" "${FINAL_CRT}.tmp"
cp "$FINAL_KEY" "${FINAL_KEY}.tmp"

# Install new certs
log_and_notify "Installing new certificates..."
mv "$TMP_CRT" "$FINAL_CRT"
mv "$TMP_KEY" "$FINAL_KEY"

# Restart Caddy
log_and_notify "Restarting Caddy service..."
if ! docker restart "$CADDY_CONTAINER_NAME"; then
    log_and_notify "Caddy restart failed" notify "Update Failed" "Service Error" "Failed to restart Caddy" "alert"
    rollback
fi

# Verify with extended timeout
log_and_notify "Waiting for Caddy to initialize..."
sleep 10
if ! verify_caddy; then
    log_and_notify "Verification failed after restart" notify "Update Failed" "Verification Error" "HTTPS test failed after update" "alert"
    rollback
fi

# Cleanup
log_and_notify "Cleaning up backup files..."
rm -f "${FINAL_CRT}.tmp" "${FINAL_KEY}.tmp"
log_and_notify "Certificate update completed successfully" notify "Update Complete" "Success" "Certificates rotated successfully" "normal"

exit 0
