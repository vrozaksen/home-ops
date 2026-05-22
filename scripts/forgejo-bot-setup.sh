#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Forgejo Renovate bot setup
#
# Creates `renovate-bot` user, generates its PAT, and adds it
# as a Write collaborator to listed repos. Required because
# ENABLE_INTERNAL_SIGNIN=false in Forgejo (Authentik-only login)
# blocks the usual "log in as bot → generate token" path.
#
# Usage:
#   1. Generate admin PAT in Forgejo: Settings → Applications
#      Scopes: write:admin + read:admin
#   2. Set ADMIN_PAT below (or export it before running)
#   3. Adjust REPOS array as new repos get migrated
#   4. Run, paste resulting bot PAT into Infisical
#      (/kubernetes/renovate/forgejo → FORGEJO_PAT)
#   5. kubectl rollout restart deploy -n renovate
# ============================================================

ADMIN_PAT="${ADMIN_PAT:-WKLEJ_TU_SWOJ_ADMIN_PAT}"

# Optional: pre-set bot password (e.g. from Bitwarden). If unset and bot user
# doesn't exist yet, the script generates a random one (discarded — bot uses PAT).
BOT_PASSWORD="${BOT_PASSWORD:-}"

# Bot avatar URL (PNG). Fetched and uploaded via Forgejo admin API.
# Required — script fails if upload doesn't succeed.
AVATAR_URL="${AVATAR_URL:-https://raw.githubusercontent.com/renovatebot/renovate/main/docs/usage/assets/images/logo.png}"

FORGEJO_URL='https://git.vzkn.eu'
BOT_USERNAME='renovate-bot'
BOT_EMAIL='renovate@vzkn.eu'
BOT_TOKEN_NAME='renovate-operator'
BOT_SCOPES='["write:repository", "read:user", "read:organization", "write:issue"]'

# Repos to grant bot Write access. Leave empty to skip the collaborator step
# (e.g. when you prefer to add collaborators manually in the Forgejo UI).
# Example:
#   REPOS=('my-repo' 'another-repo')
REPOS=()
OWNER='vrozaksen'

# ------------------------------------------------------------

[[ "$ADMIN_PAT" == "WKLEJ_TU_SWOJ_ADMIN_PAT" || -z "$ADMIN_PAT" ]] && {
  echo "❌ Set ADMIN_PAT first (edit script or export ADMIN_PAT=...)" >&2
  exit 1
}

API="$FORGEJO_URL/api/v1"
H_AUTH=(-H "Authorization: token $ADMIN_PAT")
H_JSON=(-H "Content-Type: application/json")

echo "▶ Verify admin PAT scope..."
RESP=$(curl -s -w '\n%{http_code}' "${H_AUTH[@]}" "$API/admin/users?limit=1")
HTTP_CODE=$(tail -n1 <<<"$RESP")
BODY=$(sed '$d' <<<"$RESP")
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "❌ Admin PAT verify failed (HTTP $HTTP_CODE)" >&2
  echo "   Response: $BODY" >&2
  echo "   Required scope: read:admin (and write:admin for create/PAT ops)" >&2
  exit 1
fi
echo "   ✓ admin scope confirmed"

echo "▶ Check/create bot user '$BOT_USERNAME'..."
# Use /admin/users?login_name= (admin scope) instead of /users/<name> (needs read:user)
USER_CHECK=$(curl -s -w '\n%{http_code}' "${H_AUTH[@]}" \
  "$API/admin/users?source_id=0&login_name=$BOT_USERNAME&limit=50")
UC_HTTP=$(tail -n1 <<<"$USER_CHECK")
UC_BODY=$(sed '$d' <<<"$USER_CHECK")
if [[ "$UC_HTTP" != "200" ]]; then
  echo "❌ User lookup failed (HTTP $UC_HTTP): $UC_BODY" >&2
  exit 1
fi
EXISTS=$(jq -r --arg u "$BOT_USERNAME" '[.[] | select(.login == $u)] | length' <<<"$UC_BODY")
if [[ "$EXISTS" -gt 0 ]]; then
  echo "   ✓ exists, skipping creation"
else
  BOT_PWD="${BOT_PASSWORD:-$(openssl rand -base64 32)}"
  CREATE=$(curl -s -w '\n%{http_code}' -X POST "${H_AUTH[@]}" "${H_JSON[@]}" \
    "$API/admin/users" -d @- <<EOF
{
  "username": "$BOT_USERNAME",
  "email": "$BOT_EMAIL",
  "password": "$BOT_PWD",
  "must_change_password": false,
  "send_notify": false,
  "source_id": 0
}
EOF
  )
  CR_HTTP=$(tail -n1 <<<"$CREATE")
  CR_BODY=$(sed '$d' <<<"$CREATE")
  case "$CR_HTTP" in
    201)
      if [[ -n "$BOT_PASSWORD" ]]; then
        echo "   ✓ created (with BOT_PASSWORD from env)"
      else
        echo "   ✓ created (random password — store BOT_PASSWORD in env next time if needed)"
      fi
      ;;
    422)
      # user already exists — login_name filter above missed it (Forgejo quirk)
      echo "   ✓ already exists (lookup filter missed it, treating as present)"
      ;;
    *)
      echo "❌ User creation failed (HTTP $CR_HTTP): $CR_BODY" >&2
      exit 1
      ;;
  esac
fi

echo "▶ Set bot avatar from $AVATAR_URL ..."
[[ -z "$AVATAR_URL" ]] && { echo "❌ AVATAR_URL is empty" >&2; exit 1; }

AVATAR_TMP=$(mktemp)
trap 'rm -f "$AVATAR_TMP"' EXIT
if ! curl -sfL "$AVATAR_URL" -o "$AVATAR_TMP"; then
  echo "❌ Avatar fetch failed from $AVATAR_URL" >&2
  exit 1
fi
[[ ! -s "$AVATAR_TMP" ]] && { echo "❌ Fetched avatar is empty" >&2; exit 1; }

AV_RESP=$(base64 -w0 < "$AVATAR_TMP" \
  | jq -Rn '{image: input}' \
  | curl -s -w '\n%{http_code}' -X POST "${H_AUTH[@]}" "${H_JSON[@]}" \
      -H "Sudo: $BOT_USERNAME" \
      -d @- "$API/user/avatar")
AV_HTTP=$(tail -n1 <<<"$AV_RESP")
AV_BODY=$(sed '$d' <<<"$AV_RESP")
case "$AV_HTTP" in
  204|200) echo "   ✓ avatar set" ;;
  *)
    echo "❌ Avatar upload failed (HTTP $AV_HTTP): $AV_BODY" >&2
    exit 1
    ;;
esac

echo "▶ Generate bot PAT..."
# Forgejo wymaga Basic Auth (bot username:password) na /users/{name}/tokens.
# Admin PAT + /admin/users/.../tokens nie istnieje w Forgejo.
[[ -z "$BOT_PASSWORD" ]] && {
  echo "❌ BOT_PASSWORD not set — required for PAT generation" >&2
  echo "   Forgejo's token endpoint needs Basic Auth (no admin PAT shortcut)." >&2
  echo "   export BOT_PASSWORD='<your-bot-password>' and re-run." >&2
  exit 1
}
PAT_RESP=$(curl -s -w '\n%{http_code}' -X POST \
  -u "$BOT_USERNAME:$BOT_PASSWORD" "${H_JSON[@]}" \
  "$API/users/$BOT_USERNAME/tokens" -d @- <<EOF
{
  "name": "$BOT_TOKEN_NAME-$(date +%s)",
  "scopes": $BOT_SCOPES
}
EOF
)
PAT_HTTP=$(tail -n1 <<<"$PAT_RESP")
PAT_BODY=$(sed '$d' <<<"$PAT_RESP")
if [[ "$PAT_HTTP" != "201" ]]; then
  echo "❌ PAT generation failed (HTTP $PAT_HTTP): $PAT_BODY" >&2
  echo "   Check BOT_PASSWORD is correct." >&2
  exit 1
fi
BOT_PAT=$(jq -r .sha1 <<<"$PAT_BODY")
[[ -z "$BOT_PAT" || "$BOT_PAT" == "null" ]] && {
  echo "❌ PAT generation returned no sha1: $PAT_BODY" >&2
  exit 1
}
echo "   ✓ PAT generated"

if [[ ${#REPOS[@]} -eq 0 ]]; then
  echo "▶ REPOS list empty — skipping collaborator step (add bot manually via UI)"
else
  echo "▶ Add bot as collaborator to ${#REPOS[@]} repos..."
  for repo in "${REPOS[@]}"; do
  HTTP=$(curl -so /dev/null -w '%{http_code}' -X PUT "${H_AUTH[@]}" "${H_JSON[@]}" \
    "$API/repos/$OWNER/$repo/collaborators/$BOT_USERNAME" \
    -d '{"permission": "write"}')
  case "$HTTP" in
    204) echo "   ✓ $repo (added)" ;;
    422) echo "   ⚠ $repo (already collaborator or self)" ;;
    404) echo "   ✗ $repo (repo not found — skip)" ;;
    *)   echo "   ✗ $repo (HTTP $HTTP)" ;;
  esac
  done
fi

cat <<EOF

═══════════════════════════════════════════════════════════════
✓ DONE

BOT PAT (paste into Infisical):
  Path:  /kubernetes/renovate/forgejo
  Key:   FORGEJO_PAT
  Value:

$BOT_PAT

After paste in Infisical:
  kubectl rollout restart deploy -n renovate
═══════════════════════════════════════════════════════════════
EOF
