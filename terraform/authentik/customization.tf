resource "authentik_policy_password" "password-complexity" {
  name             = "password-complexity"
  length_min       = 8
  amount_digits    = 1
  amount_lowercase = 1
  amount_uppercase = 1
  error_message    = "Minimum password length: 10. At least 1 of each required: uppercase, lowercase, digit"
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
# Extract all groups the user is a member of
groups = [group.name for group in user.ak_groups.all()]

# In Nextcloud, administrators must be members of a fixed group called "admin".

# If a user is an admin in authentik, ensure that "admin" is appended to their group list.
if user.is_superuser and "admin" not in groups:
    groups.append("admin")

# Determine quota based on group membership and admin status
quota_value = "5 GB"  # Default quota

# Priority 1: Admin users get unlimited quota ("none")
if user.is_superuser:
    quota_value = "none"
# Priority 2: Members of "Home" group get 50GB
elif "Home" in groups:
    quota_value = "50 GB"
# Priority 3: Use custom attribute if set
else:
    quota_value = user.attributes.get("nextcloud_quota", user.group_attributes().get("nextcloud_quota", "5 GB"))

return {
    "name": request.user.name,
    "groups": groups,
    # Set a quota by using the "nextcloud_quota" property in the user's attributes
    "quota": quota_value,
    # To connect an existing Nextcloud user, set "nextcloud_user_id" to the Nextcloud username.
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
