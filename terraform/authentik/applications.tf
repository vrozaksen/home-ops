locals {
  oauth_apps = [
    "autobrr",
    "coder",
    "dashbrr",
    "grafana",
    "headscale",
    "headlamp",
    "pgadmin",
    "paperless",
    "rresume",
    "outline"
  ]
}

# Step 1: Retrieve secrets from Bitwarden
data "bitwarden_secret" "application" {
  for_each = toset(local.oauth_apps)
  key      = each.key
}

# Step 2: Parse the secrets using regex to extract client_id and client_secret
locals {
  parsed_secrets = {
    for app, secret in data.bitwarden_secret.application : app => {
      client_id     = replace(regex(".*_CLIENT_ID: (\\S+)", secret.value)[0], "\"", "")
      client_secret = replace(regex(".*_CLIENT_SECRET: (\\S+)", secret.value)[0], "\"", "")
    }
  }
}

locals {
  applications = {
    autobrr = {
      client_id     = local.parsed_secrets["autobrr"].client_id
      client_secret = local.parsed_secrets["autobrr"].client_secret
      group         = "downloads"
      icon_url      = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/autobrr.png"
      redirect_uri  = "https://autobrr.${var.cluster_domain}/api/auth/oidc/callback"
      launch_url    = "https://autobrr.${var.cluster_domain}/api/auth/oidc/callback"
    },
    coder = {
      client_id     = local.parsed_secrets["coder"].client_id
      client_secret = local.parsed_secrets["coder"].client_secret
      group         = "infrastructure"
      icon_url      = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/coder-light.png"
      redirect_uri  = "https://coder.${var.cluster_domain}/api/v2/users/oidc/callback"
      launch_url    = "https://coder.${var.cluster_domain}/"
    },
    dashbrr = {
      client_id     = local.parsed_secrets["dashbrr"].client_id
      client_secret = local.parsed_secrets["dashbrr"].client_secret
      group         = "downloads"
      icon_url      = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/dashbrr.png"
      redirect_uri  = "https://dashbrr.${var.cluster_domain}/api/auth/callback"
      launch_url    = "https://dashbrr.${var.cluster_domain}/api/auth/callback"
    },
    grafana = {
      client_id     = local.parsed_secrets["grafana"].client_id
      client_secret = local.parsed_secrets["grafana"].client_secret
      group         = "monitoring"
      icon_url      = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/grafana.png"
      redirect_uri  = "https://grafana.${var.cluster_domain}/login/generic_oauth"
      launch_url    = "https://grafana.${var.cluster_domain}/login/generic_oauth"
    },
    headlamp = {
      client_id     = local.parsed_secrets["headlamp"].client_id
      client_secret = local.parsed_secrets["headlamp"].client_secret
      group         = "infrastructure"
      icon_url      = "https://raw.githubusercontent.com/headlamp-k8s/headlamp/refs/heads/main/frontend/src/resources/icon-dark.svg"
      redirect_uri  = "https://headlamp.${var.cluster_domain}/oidc-callback"
      launch_url    = "https://headlamp.${var.cluster_domain}/"
    },
    headscale = {
      client_id     = local.parsed_secrets["headscale"].client_id
      client_secret = local.parsed_secrets["headscale"].client_secret
      group         = "infrastructure"
      icon_url      = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/headscale.png"
      redirect_uri  = "https://headscale.${var.cluster_domain}/oidc/callback"
      launch_url    = "https://headscale.${var.cluster_domain}/"
    },
    pgadmin = {
      client_id     = local.parsed_secrets["pgadmin"].client_id
      client_secret = local.parsed_secrets["pgadmin"].client_secret
      group         = "infrastructure"
      icon_url      = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/pgadmin.png"
      redirect_uri  = "https://pgadmin.${var.cluster_domain}/oauth2/authorize"
      launch_url    = "https://pgadmin.${var.cluster_domain}/"
    },
    outline = {
      client_id     = local.parsed_secrets["outline"].client_id
      client_secret = local.parsed_secrets["outline"].client_secret
      group         = "home"
      icon_url      = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/outline.png"
      redirect_uri  = "https://docs.${var.cluster_domain}/auth/oidc.callback"
      launch_url    = "https://docs.${var.cluster_domain}/"
    },
    paperless = {
      client_id     = local.parsed_secrets["paperless"].client_id
      client_secret = local.parsed_secrets["paperless"].client_secret
      group         = "home"
      icon_url      = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/paperless-ngx.png"
      redirect_uri  = "https://paperless.${var.cluster_domain}/accounts/oidc/authentik/login/callback/"
      launch_url    = "https://paperless.${var.cluster_domain}/"
    },
    rresume = {
      client_id     = local.parsed_secrets["rresume"].client_id
      client_secret = local.parsed_secrets["rresume"].client_secret
      group         = "home"
      icon_url      = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/reactive-resume.png"
      redirect_uri  = "https://rr.${var.cluster_domain}/api/auth/openid/callback"
      launch_url    = "https://rr.${var.cluster_domain}/"
    }
  }
}

resource "authentik_provider_oauth2" "oauth2" {
  for_each              = local.applications
  name                  = each.key
  client_id             = each.value.client_id
  client_secret         = each.value.client_secret
  authorization_flow    = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow   = authentik_flow.authentication.uuid
  invalidation_flow     = data.authentik_flow.default-provider-invalidation-flow.id
  property_mappings     = data.authentik_property_mapping_provider_scope.oauth2.ids
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = each.value.redirect_uri,
    }
  ]
}

resource "authentik_application" "application" {
  for_each           = local.applications
  name               = title(each.key)
  slug               = each.key
  protocol_provider  = authentik_provider_oauth2.oauth2[each.key].id
  group              = authentik_group.default[each.value.group].name
  open_in_new_tab    = true
  meta_icon          = each.value.icon_url
  meta_launch_url    = each.value.launch_url
  policy_engine_mode = "all"
}
