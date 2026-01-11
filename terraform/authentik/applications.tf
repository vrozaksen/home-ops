locals {
  oauth_apps = [
    "unraid",
    #  "coder",
    "flux",
    "forgejo",
    "grafana",
    # "harbor",
    "headlamp",
    # "karakeep",
    # "miniflux",
    "nextcloud",
    # "open-webui",
    "pgadmin",
    "rxresume"
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
      client_id = replace(
        regex(".*_CLIENT_ID: (\\S+)", secret.value)[0],
        "\"", ""
      )
      client_secret = try(
        replace(regex(".*_CLIENT_SECRET: (\\S+)", secret.value)[0], "\"", ""),
        null
      )
    } if can(regex("_CLIENT_ID:", secret.value))
  }
}

# NAS
module "oauth2-unraid" {
  source                       = "./oauth2_application"
  name                         = "UnRaid"
  icon_url                     = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/unraid.png"
  launch_url                   = "https://aincrad.home.${var.cluster_domain}:4443"
  description                  = "NAS"
  newtab                       = true
  group                        = "Infrastructure"
  auth_groups                  = [authentik_group.infrastructure.id]
  authorization_flow           = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow            = resource.authentik_flow.provider-invalidation.uuid
  client_id                    = local.parsed_secrets["unraid"].client_id
  client_secret                = local.parsed_secrets["unraid"].client_secret
  additional_property_mappings = [authentik_property_mapping_provider_scope.groups.id]
  redirect_uris = [
    "https://aincrad.home.${var.cluster_domain}:4443/graphql/api/auth/oidc/callback"
  ]
}

# Downloads
module "proxy-prowlarr" {
  source             = "./proxy_application"
  name               = "Prowlarr"
  description        = "Torrent indexer"
  icon_url           = "https://raw.githubusercontent.com/Prowlarr/Prowlarr/develop/Logo/128.png"
  group              = "Downloads"
  slug               = "prowlarr"
  domain             = var.cluster_domain
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  auth_groups        = [authentik_group.media.id]
}

module "proxy-radarr" {
  source             = "./proxy_application"
  name               = "Radarr"
  description        = "Movies"
  icon_url           = "https://github.com/Radarr/Radarr/raw/develop/Logo/128.png"
  group              = "Downloads"
  slug               = "radarr"
  domain             = var.cluster_domain
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  auth_groups        = [authentik_group.media.id]
}

module "proxy-sonarr" {
  source             = "./proxy_application"
  name               = "Sonarr"
  description        = "TV"
  icon_url           = "https://github.com/Sonarr/Sonarr/raw/develop/Logo/128.png"
  group              = "Downloads"
  slug               = "sonarr"
  domain             = var.cluster_domain
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  auth_groups        = [authentik_group.media.id]
}

# module "proxy-lidarr" {
#   source             = "./proxy_application"
#   name               = "Lidarr"
#   description        = "Music"
#   icon_url           = "https://github.com/Lidarr/Lidarr/raw/develop/Logo/128.png"
#   group              = "Downloads"
#   slug               = "lidarr"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.media.id]
# }

module "proxy-bazarr" {
  source             = "./proxy_application"
  name               = "Bazarr"
  description        = "Subtitles"
  icon_url           = "https://github.com/morpheus65535/bazarr/raw/master/frontend/public/images/logo128.png"
  group              = "Downloads"
  slug               = "bazarr"
  domain             = var.cluster_domain
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  auth_groups        = [authentik_group.media.id]
}

## Media

## Infrastructure
module "oauth2-flux" {
  source             = "./oauth2_application"
  name               = "Flux"
  icon_url           = "https://raw.githubusercontent.com/fluxcd/flux2/main/docs/dev-guides/flux.png"
  launch_url         = "https://flux.${var.cluster_domain}"
  description        = "GitOps Status Page"
  newtab             = true
  group              = "Infrastructure"
  auth_groups        = [authentik_group.infrastructure.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["flux"].client_id
  client_secret      = local.parsed_secrets["flux"].client_secret
  redirect_uris      = ["https://flux.${var.cluster_domain}/oauth2/callback"]
}

module "oauth2-grafana" {
  source             = "./oauth2_application"
  name               = "Grafana"
  icon_url           = "https://raw.githubusercontent.com/grafana/grafana/main/public/img/icons/mono/grafana.svg"
  launch_url         = "https://grafana.${var.cluster_domain}"
  description        = "Observability"
  newtab             = true
  group              = "Infrastructure"
  auth_groups        = [authentik_group.infrastructure.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["grafana"].client_id
  client_secret      = local.parsed_secrets["grafana"].client_secret
  redirect_uris      = ["https://grafana.${var.cluster_domain}/login/generic_oauth"]
}

# module "oauth2-harbor" {
#   source                       = "./oauth2_application"
#   name                         = "Harbor"
#   icon_url                     = "https://raw.githubusercontent.com/goharbor/harbor/refs/heads/main/docs/img/harbor_logo.png"
#   launch_url                   = "https://harbor.${var.cluster_domain}"
#   description                  = "Container Registry"
#   newtab                       = true
#   group                        = "Development"
#   auth_groups                  = [authentik_group.infrastructure.id]
#   authorization_flow           = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow            = resource.authentik_flow.provider-invalidation.uuid
#   client_id                    = local.parsed_secrets["harbor"].client_id
#   client_secret                = local.parsed_secrets["harbor"].client_secret
#   additional_property_mappings = [authentik_property_mapping_provider_scope.groups.id]
#   redirect_uris = [
#     "https://harbor.${var.cluster_domain}/c/oidc/callback"
#   ]
# }

module "oauth2-headlamp" {
  source             = "./oauth2_application"
  name               = "Headlamp"
  icon_url           = "https://raw.githubusercontent.com/headlamp-k8s/headlamp/refs/heads/main/frontend/src/resources/icon-dark.svg"
  launch_url         = "https://headlamp.${var.cluster_domain}"
  description        = "Kubernetes tooling"
  newtab             = true
  group              = "Infrastructure"
  auth_groups        = [authentik_group.infrastructure.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["headlamp"].client_id
  client_secret      = local.parsed_secrets["headlamp"].client_secret
  redirect_uris      = ["https://headlamp.${var.cluster_domain}/oidc-callback"]
}

## Development
# module "oauth2-coder" {
#   source             = "./oauth2_application"
#   name               = "Coder"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/coder.png"
#   launch_url         = "https://coder.${var.cluster_domain}"
#   description        = "Cloud Development Environments"
#   newtab             = true
#   group              = "Development"
#   auth_groups        = [authentik_group.infrastructure.id]
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   client_id          = local.parsed_secrets["coder"].client_id
#   client_secret      = local.parsed_secrets["coder"].client_secret
#   redirect_uris      = ["https://coder.${var.cluster_domain}/api/v2/users/oidc/callback"]
# }

module "oauth2-forgejo" {
  source             = "./oauth2_application"
  name               = "Forgejo"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/forgejo.png"
  launch_url         = "https://forgejo.${var.cluster_domain}"
  description        = "Git Forge"
  newtab             = true
  group              = "Development"
  auth_groups        = [authentik_group.users.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["forgejo"].client_id
  client_secret      = local.parsed_secrets["forgejo"].client_secret
  redirect_uris      = ["https://forgejo.${var.cluster_domain}/user/oauth2/Authentik/callback"]
}

module "oauth2-pgadmin" {
  source             = "./oauth2_application"
  name               = "Pgadmin"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/pgadmin.png"
  launch_url         = "https://pgadmin.${var.cluster_domain}"
  description        = "Postgres Manager"
  newtab             = true
  group              = "Infrastructure"
  auth_groups        = [authentik_group.infrastructure.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["pgadmin"].client_id
  client_secret      = local.parsed_secrets["pgadmin"].client_secret
  redirect_uris      = ["https://pgadmin.${var.cluster_domain}/oauth2/authorize"]
}

## Home
# module "oauth2-karakeep" {
#   source             = "./oauth2_application"
#   name               = "Karakeep"
#   icon_url           = "https://raw.githubusercontent.com/karakeep-app/karakeep/refs/heads/main/docs/static/img/logo.png"
#   launch_url         = "https://karakeep.${var.cluster_domain}"
#   description        = "Karakeep"
#   newtab             = true
#   group              = "Home"
#   auth_groups        = [authentik_group.users.id]
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   client_id          = local.parsed_secrets["karakeep"].client_id
#   client_secret      = local.parsed_secrets["karakeep"].client_secret
#   redirect_uris      = ["https://karakeep.${var.cluster_domain}/api/auth/callback/custom"]
# }

# module "oauth2-miniflux" {
#   source             = "./oauth2_application"
#   name               = "Miniflux"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/miniflux.png"
#   launch_url         = "https://miniflux.${var.cluster_domain}"
#   description        = "RSS"
#   newtab             = true
#   group              = "Home"
#   auth_groups        = [authentik_group.home.id]
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   client_id          = local.parsed_secrets["miniflux"].client_id
#   client_secret      = local.parsed_secrets["miniflux"].client_secret
#   redirect_uris      = ["https://miniflux.${var.cluster_domain}/oauth2/oidc/callback"]
# }

module "oauth2-nextcloud" {
  source             = "./oauth2_application"
  name               = "Nextcloud"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/nextcloud.png"
  launch_url         = "https://cloud.${var.cluster_domain}"
  description        = "Cloud Storage & Collaboration"
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.users.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["nextcloud"].client_id
  client_secret      = local.parsed_secrets["nextcloud"].client_secret
  redirect_uris = [
    "https://cloud.${var.cluster_domain}/apps/user_oidc/code"
  ]
}

# module "oauth2-paperless" {
#   source             = "./oauth2_application"
#   name               = "Paperless"
#   icon_url           = "https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/dev/resources/logo/web/svg/Color%20logo%20-%20no%20background.svg"
#   launch_url         = "https://docs.${var.cluster_domain}"
#   description        = "Documents"
#   newtab             = true
#   group              = "Home"
#   auth_groups        = [authentik_group.home.id]
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   client_id          = local.parsed_secrets["paperless"].client_id
#   client_secret      = local.parsed_secrets["paperless"].client_secret
#   redirect_uris      = ["https://docs.${var.cluster_domain}/accounts/oidc/authentik/login/callback/"]
# }

module "oauth2-rxresume" {
  source             = "./oauth2_application"
  name               = "Reactive-Resume"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/reactive-resume.png"
  launch_url         = "https://rxresume.${var.cluster_domain}"
  description        = "CV"
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.home.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["rxresume"].client_id
  client_secret      = local.parsed_secrets["rxresume"].client_secret
  redirect_uris      = ["https://rxresume.${var.cluster_domain}/api/auth/openid/callback"]
}

## Users
# module "oauth2-open-webui" {
#   source             = "./oauth2_application"
#   name               = "Open-WebUI"
#   icon_url           = "https://raw.githubusercontent.com/open-webui/open-webui/refs/heads/main/static/favicon.png"
#   launch_url         = "https://chat.${var.cluster_domain}/auth"
#   description        = "Chat"
#   newtab             = true
#   group              = "Home"
#   auth_groups        = [authentik_group.home.id]
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   client_id          = local.parsed_secrets["open-webui"].client_id
#   client_secret      = local.parsed_secrets["open-webui"].client_secret
#   redirect_uris      = ["https://chat.${var.cluster_domain}/oauth/oidc/callback"]
# }
