#!/bin/bash

# Configuration
INFISICAL_UNIVERSAL_AUTH_CLIENT_ID=""
INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET=""
INFISICAL_API_URL="https://eu.infisical.com/api"
INFISICAL_PROJECT_ID="da94b011-9a7d-408b-92d9-55be47efe750"
INFISICAL_SECRET_PATH="/kubernetes/network/certificates-import"
CADDY_CERT_DIR="/mnt/blaze/appdata/caddy/data/certificates"
CADDY_CONTAINER_NAME="caddy"
CADDY_TEST_URL="https://s3c.vzkn.eu"
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

# Fetch a secret from Infisical via API
fetch_infisical_secret() {
    local secret_name="$1"
    # Get access token via universal auth
    local token_response
    token_response=$(curl --silent --request POST \
        "${INFISICAL_API_URL}/v1/auth/universal-auth/login" \
        --header "Content-Type: application/json" \
        --data "{\"clientId\": \"${INFISICAL_UNIVERSAL_AUTH_CLIENT_ID}\", \"clientSecret\": \"${INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET}\"}")
    local access_token
    access_token=$(echo "$token_response" | jq -r '.accessToken')
    if [[ -z "$access_token" || "$access_token" == "null" ]]; then
        log_and_notify "Failed to authenticate with Infisical" notify "Update Failed" "Auth Error" "Infisical authentication failed" "alert"
        exit 1
    fi
    # Fetch the secret
    local secret_response
    secret_response=$(curl --silent --request GET \
        "${INFISICAL_API_URL}/v3/secrets/raw/${secret_name}?workspaceId=${INFISICAL_PROJECT_ID}&environment=prod&secretPath=${INFISICAL_SECRET_PATH}" \
        --header "Authorization: Bearer ${access_token}")
    echo "$secret_response" | jq -r '.secret.secretValue'
}

# Main execution
log_and_notify "Starting certificate update" notify "Certificate Update" "Starting" "Beginning certificate rotation" "normal"

# File paths
TMP_CRT="${CADDY_CERT_DIR}/certificate.crt.tmp"
TMP_KEY="${CADDY_CERT_DIR}/certificate.key.tmp"
FINAL_CRT="${CADDY_CERT_DIR}/wildcard.crt"
FINAL_KEY="${CADDY_CERT_DIR}/wildcard.key"

# Fetch certificate
log_and_notify "Retrieving certificate from Infisical..."
TLS_CRT=$(fetch_infisical_secret "TLS_CRT")
if [[ -z "$TLS_CRT" || "$TLS_CRT" == "null" ]] || ! echo "$TLS_CRT" | base64 -d > "$TMP_CRT"; then
    log_and_notify "Certificate retrieval failed" notify "Update Failed" "Certificate Error" "Failed to decode certificate" "alert"
    exit 1
fi

# Fetch private key
log_and_notify "Retrieving private key from Infisical..."
TLS_KEY=$(fetch_infisical_secret "TLS_KEY")
if [[ -z "$TLS_KEY" || "$TLS_KEY" == "null" ]] || ! echo "$TLS_KEY" | base64 -d > "$TMP_KEY"; then
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
