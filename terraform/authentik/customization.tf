## Reputation policy — brute force protection
## Score -1 per failed login; blocked when score drops below threshold
## Resets on successful login; can be manually cleared in Admin → Events → Reputation
resource "authentik_policy_reputation" "brute-force" {
  name           = "brute-force-protection"
  check_ip       = true
  check_username = true
  threshold      = -5
}

resource "authentik_policy_binding" "authentication-reputation" {
  target = authentik_flow.authentication.uuid
  policy = authentik_policy_reputation.brute-force.id
  order  = 0
}

## GeoIP policy — block high-risk countries (same list as bifrost VPS iptables)
resource "authentik_policy_geoip" "block-countries" {
  name      = "block-countries"
  countries = ["RU", "CN", "KP", "IR", "BY", "CU"]

  check_impossible_travel = true
  impossible_tolerance_km = 500
  check_history_distance  = true
  history_login_count     = 5
  history_max_distance_km = 1000
}

resource "authentik_policy_binding" "authentication-block-countries" {
  target = authentik_flow.authentication.uuid
  policy = authentik_policy_geoip.block-countries.id
  order  = 1
  negate = true # match = deny (countries list acts as blocklist)
}

## GeoIP policy — block GAFAM ASNs (same list as CrowdSec on bifrost)
resource "authentik_policy_geoip" "block-gafam-asn" {
  name = "block-gafam-asn"
  asns = [
    15169, 396982,     # Google
    714, 6185,         # Apple
    32934, 63293,      # Meta
    16509, 14618,      # Amazon
    8075, 8068, 3598,  # Microsoft
  ]
}

resource "authentik_policy_binding" "authentication-block-gafam" {
  target = authentik_flow.authentication.uuid
  policy = authentik_policy_geoip.block-gafam-asn.id
  order  = 2
  negate = true # match = deny
}

resource "authentik_policy_password" "password-complexity" {
  name             = "password-complexity"
  length_min       = 10
  amount_digits    = 1
  amount_lowercase = 1
  amount_uppercase = 1
  amount_symbols   = 1
  error_message    = "Minimum 10 characters with at least 1: uppercase, lowercase, digit, symbol"
}


resource "authentik_policy_expression" "user-settings-authorization" {
  name       = "user-settings-authorization"
  expression = <<-EOT
  from authentik.lib.config import CONFIG
  from authentik.core.models import (
      USER_ATTRIBUTE_CHANGE_EMAIL,
      USER_ATTRIBUTE_CHANGE_NAME,
      USER_ATTRIBUTE_CHANGE_USERNAME
  )
  prompt_data = request.context.get('prompt_data')

  if not request.user.group_attributes(request.http_request).get(
      USER_ATTRIBUTE_CHANGE_EMAIL, CONFIG.y_bool('default_user_change_email', True)
  ):
      if prompt_data.get('email') != request.user.email:
          ak_message('Not allowed to change email address.')
          return False

  if not request.user.group_attributes(request.http_request).get(
      USER_ATTRIBUTE_CHANGE_NAME, CONFIG.y_bool('default_user_change_name', True)
  ):
      if prompt_data.get('name') != request.user.name:
          ak_message('Not allowed to change name.')
          return False

  if not request.user.group_attributes(request.http_request).get(
      USER_ATTRIBUTE_CHANGE_USERNAME, CONFIG.y_bool('default_user_change_username', True)
  ):
      if prompt_data.get('username') != request.user.username:
          ak_message('Not allowed to change username.')
          return False

  return True
  EOT
}
resource "authentik_property_mapping_provider_scope" "openid-nextcloud" {
  name       = "OAuth Mapping: OpenID 'nextcloud'"
  scope_name = "nextcloud"
  expression = <<EOF
groups = [group.name for group in user.ak_groups.all()]

# Nextcloud admin group mapping
if user.is_superuser and "admin" not in groups:
    groups.append("admin")
if "nextcloudAdmin" in groups and "admin" not in groups:
    groups.append("admin")

# Quota: unlimited for all, or use custom attribute if set
quota_value = user.attributes.get("nextcloud_quota", "none")

return {
    "name": request.user.name,
    "groups": groups,
    "quota": quota_value,
    "user_id": user.attributes.get("nextcloud_user_id", str(user.uuid)),
}
EOF
}

# Group membership scope for Unraid and other apps
resource "authentik_property_mapping_provider_scope" "groups" {
  name        = "OAuth Mapping: Groups"
  scope_name  = "groups"
  description = "Group membership - see which groups the user belongs to"
  expression  = <<EOF
return {
    "groups": [group.name for group in user.ak_groups.all()]
}
EOF
}
