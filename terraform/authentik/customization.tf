resource "authentik_policy_password" "password-complexity" {
  name             = "password-complexity"
  length_min       = 10
  amount_digits    = 1
  amount_lowercase = 1
  amount_uppercase = 1
  amount_symbols   = 1
  error_message    = "Minimum 10 characters with at least 1: uppercase, lowercase, digit, symbol"
}

# Block users/IPs after failed login attempts
# Score: -1 per failed login, +1 per success, expires after 24h (default)
resource "authentik_policy_reputation" "login-failure-protection" {
  name             = "login-failure-protection"
  check_ip         = true
  check_username   = true
  threshold        = -10
}

# Map GitHub profile data to authentik user
resource "authentik_property_mapping_source_oauth" "github-avatar" {
  name       = "GitHub Avatar"
  expression = <<-EOF
return {
    "avatar": source.get("avatar_url"),
}
EOF
}

resource "authentik_property_mapping_source_oauth" "github-profile" {
  name       = "GitHub Profile"
  expression = <<-EOF
return {
    "attributes": {
        "github_username": source.get("login"),
        "github_bio": source.get("bio", ""),
        "github_company": source.get("company", ""),
        "github_location": source.get("location", ""),
        "github_url": source.get("html_url"),
    }
}
EOF
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
