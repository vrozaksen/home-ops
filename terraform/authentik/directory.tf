locals {
  authentik_groups = {
    downloads      = { name = "Downloads" }
    home           = { name = "Home" }
    infrastructure = { name = "Infrastructure" }
    media          = { name = "Media" }
    monitoring     = { name = "Monitoring" }
    users          = { name = "Users" }
    ocis_admin     = { name = "OCIS-Admin" }
    ocis           = { name = "OCIS" }
  }
}

data "authentik_group" "admins" {
  name = "authentik Admins"
}

resource "authentik_group" "grafana_admin" {
  name         = "Grafana Admins"
  is_superuser = false
}

resource "authentik_group" "default" {
  for_each     = local.authentik_groups
  name         = each.value.name
  is_superuser = false
}

resource "authentik_policy_binding" "application_policy_binding" {
  for_each = local.applications

  target = authentik_application.application[each.key].uuid
  group  = authentik_group.default[each.value.group].id
  order  = 0
}

data "bitwarden_secret" "discord" {
  key = "discord"
}

data "bitwarden_secret" "github" {
  key = "github"
}

locals {
  discord_client_id     = replace(regex("DISCORD_CLIENT_ID: (\\S+)", data.bitwarden_secret.discord.value)[0], "\"", "")
  discord_client_secret = replace(regex("DISCORD_CLIENT_SECRET: (\\S+)", data.bitwarden_secret.discord.value)[0], "\"", "")
  github_client_id      = replace(regex("GITHUB_CLIENT_ID: (\\S+)", data.bitwarden_secret.github.value)[0], "\"", "")
  github_client_secret  = replace(regex("GITHUB_CLIENT_SECRET: (\\S+)", data.bitwarden_secret.github.value)[0], "\"", "")
}

##Oauth
resource "authentik_source_oauth" "discord" {
  name                = "Discord"
  slug                = "discord"
  authentication_flow = data.authentik_flow.default-source-authentication.id
  enrollment_flow     = authentik_flow.enrollment-invitation.uuid
  user_matching_mode  = "email_deny"

  provider_type   = "discord"
  consumer_key    = local.discord_client_id
  consumer_secret = local.discord_client_secret
}

resource "authentik_source_oauth" "github" {
  name                = "Github"
  slug                = "github"
  authentication_flow = data.authentik_flow.default-source-authentication.id
  enrollment_flow     = authentik_flow.enrollment-invitation.uuid
  user_matching_mode  = "email_deny"

  provider_type   = "github"
  consumer_key    = local.github_client_id
  consumer_secret = local.github_client_secret
}
