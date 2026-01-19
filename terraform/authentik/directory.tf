data "authentik_group" "admins" {
  name = "authentik Admins"
}

resource "authentik_group" "superusers" {
  name = "superusers"
}

resource "authentik_group" "grafana_admin" {
  name         = "Grafana Admins"
  is_superuser = false
}

resource "authentik_group" "users" {
  name         = "users"
  is_superuser = false
}

resource "authentik_group" "media" {
  name         = "media"
  is_superuser = false
  parents      = [authentik_group.users.id]
  # attributes = jsonencode({
  #   defaultQuota = "5 GB"
  # })
}

resource "authentik_group" "home" {
  name         = "home"
  is_superuser = false
  parents      = [authentik_group.users.id]
}


resource "authentik_group" "infrastructure" {
  name         = "infrastructure"
  is_superuser = false
}

resource "authentik_group" "public" {
  name         = "public"
  is_superuser = false
}

resource "authentik_group" "nextcloudAdmin" {
  name         = "nextcloudAdmin"
  is_superuser = false
}

resource "authentik_group" "admin" {
  name         = "admin"
  is_superuser = false
}

# data "bitwarden_secret" "discord" {
#   key = "discord"
# }

data "bitwarden_secret" "github" {
  key = "github"
}

locals {
  # discord_client_id     = replace(regex("DISCORD_CLIENT_ID: (\\S+)", data.bitwarden_secret.discord.value)[0], "\"", "")
  # discord_client_secret = replace(regex("DISCORD_CLIENT_SECRET: (\\S+)", data.bitwarden_secret.discord.value)[0], "\"", "")
  github_client_id     = replace(regex("GITHUB_CLIENT_ID: (\\S+)", data.bitwarden_secret.github.value)[0], "\"", "")
  github_client_secret = replace(regex("GITHUB_CLIENT_SECRET: (\\S+)", data.bitwarden_secret.github.value)[0], "\"", "")
}

##Oauth
# resource "authentik_source_oauth" "discord" {
#   name                = "Discord"
#   slug                = "discord"
#   authentication_flow = data.authentik_flow.default-source-authentication.id
#   enrollment_flow     = authentik_flow.enrollment-invitation.uuid
#   user_matching_mode  = "email_link"

#   provider_type   = "discord"
#   consumer_key    = local.discord_client_id
#   consumer_secret = local.discord_client_secret

#   additional_scopes = "identify email"
# }

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

resource "authentik_policy_binding" "github_superusers_only" {
  target = authentik_source_oauth.github.uuid
  group  = authentik_group.superusers.id
  order  = 0
}
