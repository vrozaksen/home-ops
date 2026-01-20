## Built-in groups
data "authentik_group" "admins" {
  name = "authentik Admins"
}

## Service Accounts

# LDAP bind service account for applications (Emby, etc.)
resource "authentik_user" "ldap-service" {
  username = "ldap-service"
  name     = "LDAP Service Account"
  email    = "ldap-service@${var.cluster_domain}"
  password = local.ldap_service_password
  type     = "service_account"
  groups   = [authentik_group.users.id]
  attributes = jsonencode({
    "goauthentik.io/user/service-account" = true
  })
}

## Groups

# Pending - new registrations, no app access (admin approves to users)
resource "authentik_group" "pending" {
  name         = "pending"
  is_superuser = false
}

# Users - approved users with access to: Forgejo, Nextcloud, RxResume, Sentry
resource "authentik_group" "users" {
  name         = "users"
  is_superuser = false
}

# Admin - full access (Downloads, Infrastructure, + everything users have)
resource "authentik_group" "admin" {
  name         = "admin"
  is_superuser = false
  parents      = [authentik_group.users.id]
}

# Nextcloud administrators (for group sync)
resource "authentik_group" "nextcloudAdmin" {
  name         = "nextcloudAdmin"
  is_superuser = false
  parents      = [authentik_group.users.id]
}

## OAuth Sources

data "bitwarden_secret" "github" {
  key = "github"
}

locals {
  github_client_id     = replace(regex("GITHUB_CLIENT_ID: (\\S+)", data.bitwarden_secret.github.value)[0], "\"", "")
  github_client_secret = replace(regex("GITHUB_CLIENT_SECRET: (\\S+)", data.bitwarden_secret.github.value)[0], "\"", "")
}

resource "authentik_source_oauth" "github" {
  name                = "GitHub"
  slug                = "github"
  authentication_flow = data.authentik_flow.default-source-authentication.id
  enrollment_flow     = authentik_flow.enrollment-invitation.uuid
  user_matching_mode  = "email_link"

  provider_type   = "github"
  consumer_key    = local.github_client_id
  consumer_secret = local.github_client_secret

  additional_scopes = "read:user user:email"

}
