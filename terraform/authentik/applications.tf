locals {
  oauth_apps = [
    "gitea",
    "grafana",
    "headlamp",
    "mealie",
    "miniflux",
    "mirotalk",
    "nextcloud",
    "outline",
    "paperless",
    "pgadmin",
    "rresume",
    "vikunja",
    "zipline"
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

# module "proxy-navidrome" {
#   source             = "./proxy_application"
#   name               = "Navidrome"
#   description        = "Music player"
#   icon_url           = "https://github.com/navidrome/navidrome/raw/master/resources/logo-192x192.png"
#   group              = "Selfhosted"
#   slug               = "navidrome"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.media.id]
#   ignore_paths       = <<-EOT
#   /rest/*
#   /share/*
#   EOT
# }

## Media

## Infrastructure
module "oauth2-gitea" {
  source             = "./oauth2_application"
  name               = "Gitea"
  icon_url           = "https://raw.githubusercontent.com/go-gitea/gitea/refs/heads/main/public/assets/img/logo.png"
  launch_url         = "https://gitea.${var.cluster_domain}"
  description        = "Version control"
  newtab             = true
  group              = "Infrastructure"
  auth_groups        = [authentik_group.infrastructure.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["gitea"].client_id
  client_secret      = local.parsed_secrets["gitea"].client_secret
  redirect_uris      = ["https://gitea.${var.cluster_domain}/user/oauth2/Authentik/callback"]
}

module "oauth2-grafana" {
  source             = "./oauth2_application"
  name               = "Grafana"
  icon_url           = "https://raw.githubusercontent.com/grafana/grafana/main/public/img/icons/mono/grafana.svg"
  launch_url         = "https://grafana.${var.cluster_domain}"
  description        = "Infrastructure graphs"
  newtab             = true
  group              = "Infrastructure"
  auth_groups        = [authentik_group.infrastructure.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["grafana"].client_id
  client_secret      = local.parsed_secrets["grafana"].client_secret
  redirect_uris      = ["https://grafana.${var.cluster_domain}/login/generic_oauth"]
}

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
module "oauth2-mealie" {
  source             = "./oauth2_application"
  name               = "Mealie"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/mealie.png"
  launch_url         = "https://mealie.${var.cluster_domain}"
  description        = "Recipes"
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.home.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["mealie"].client_id
  client_secret      = local.parsed_secrets["mealie"].client_secret
  redirect_uris      = ["https://mealie.${var.cluster_domain}/login"]
}

module "oauth2-miniflux" {
  source             = "./oauth2_application"
  name               = "Miniflux"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/miniflux.png"
  launch_url         = "https://miniflux.${var.cluster_domain}"
  description        = "RSS"
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.home.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["miniflux"].client_id
  client_secret      = local.parsed_secrets["miniflux"].client_secret
  redirect_uris      = ["https://miniflux.${var.cluster_domain}/oauth2/oidc/callback"]
}

module "oauth2-outline" {
  source             = "./oauth2_application"
  name               = "Outline"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/outline.png"
  launch_url         = "https://outline.${var.cluster_domain}"
  description        = "Outline Desc" # TODO
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.home.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["outline"].client_id
  client_secret      = local.parsed_secrets["outline"].client_secret
  redirect_uris      = ["https://outline.${var.cluster_domain}/auth/oidc.callback"]
}

module "oauth2-paperless" {
  source             = "./oauth2_application"
  name               = "Paperless"
  icon_url           = "https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/dev/resources/logo/web/svg/Color%20logo%20-%20no%20background.svg"
  launch_url         = "https://docs.${var.cluster_domain}"
  description        = "Documents"
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.home.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["paperless"].client_id
  client_secret      = local.parsed_secrets["paperless"].client_secret
  redirect_uris      = ["https://docs.${var.cluster_domain}/accounts/oidc/authentik/login/callback/"]
}

module "oauth2-rresume" {
  source             = "./oauth2_application"
  name               = "Reactive-Resume"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/reactive-resume.png"
  launch_url         = "https://rr.${var.cluster_domain}"
  description        = "CV"
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.home.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["rresume"].client_id
  client_secret      = local.parsed_secrets["rresume"].client_secret
  redirect_uris      = ["https://rr.${var.cluster_domain}/api/auth/openid/callback"]
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

module "oauth2-mirotalk" {
  source             = "./oauth2_application"
  name               = "MiroTalk"
  icon_url           = "https://raw.githubusercontent.com/miroslavpejic85/mirotalk/refs/heads/master/public/images/mirotalk-logo.png"
  launch_url         = "https://mirotalk.${var.cluster_domain}"
  description        = "MiroTalk"
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.users.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["mirotalk"].client_id
  client_secret      = local.parsed_secrets["mirotalk"].client_secret
  redirect_uris      = ["https://mirotalk.${var.cluster_domain}/auth/callback"]
}

module "oauth2-vikunja" {
  source             = "./oauth2_application"
  name               = "Vikunja"
  icon_url           = "https://raw.githubusercontent.com/go-vikunja/vikunja/refs/heads/main/frontend/public/images/icons/android-chrome-512x512.png"
  launch_url         = "https://vikunja.${var.cluster_domain}/auth/openid/"
  description        = "Vikunja"
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.users.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["vikunja"].client_id
  client_secret      = local.parsed_secrets["vikunja"].client_secret
  redirect_uris      = ["https://vikunja.${var.cluster_domain}/auth/openid/"]
}

module "oauth2-zipline" {
  source             = "./oauth2_application"
  name               = "Zipline"
  icon_url           = "https://raw.githubusercontent.com/diced/zipline/refs/heads/trunk/public/favicon-512x512.png"
  launch_url         = "https://z.${var.cluster_domain}"
  description        = "FileBin"
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.users.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["zipline"].client_id
  client_secret      = local.parsed_secrets["zipline"].client_secret
  redirect_uris      = ["https://z.${var.cluster_domain}/api/auth/oauth/oidc"]
}

# module "oauth2-immich" {
#   source             = "./oauth2_application"
#   name               = "Immich"
#   icon_url           = "https://github.com/immich-app/immich/raw/main/docs/static/img/favicon.png"
#   launch_url         = "https://photos.${var.cluster_domain}"
#   description        = "Photo managment"
#   newtab             = true
#   group              = "Selfhosted"
#   auth_groups        = [authentik_group.media.id]
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   client_id          = module.secret_immich.fields["OIDC_CLIENT_ID"]
#   client_secret      = module.secret_immich.fields["OIDC_CLIENT_SECRET"]
#   redirect_uris = [
#     "https://photos.${var.cluster_domain}/auth/login",
#     "app.immich:///oauth-callback"
#   ]
# }

module "oauth2-nextcloud" {
  source                       = "./oauth2_application"
  name                         = "Nextcloud"
  icon_url                     = "https://upload.wikimedia.org/wikipedia/commons/6/60/Nextcloud_Logo.svg"
  launch_url                   = "https://cloud.${var.cluster_domain}"
  description                  = "Files"
  newtab                       = true
  group                        = "Selfhosted"
  auth_groups                  = [authentik_group.users.id]
  authorization_flow           = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow            = resource.authentik_flow.provider-invalidation.uuid
  client_id                    = local.parsed_secrets["nextcloud"].client_id
  client_secret                = local.parsed_secrets["nextcloud"].client_secret
  include_claims_in_id_token   = false
  additional_property_mappings = formatlist(authentik_property_mapping_provider_scope.openid-nextcloud.id)
  sub_mode                     = "user_username"
  redirect_uris                = ["https://cloud.${var.cluster_domain}/apps/oidc_login/oidc"]
}

# module "oauth2-romm" {
#   source             = "./oauth2_application"
#   name               = "Romm"
#   icon_url           = "https://raw.githubusercontent.com/rommapp/romm/refs/heads/release/frontend/assets/isotipo.svg"
#   launch_url         = "https://romm.${var.cluster_domain}"
#   description        = "Games"
#   newtab             = true
#   group              = "Selfhosted"
#   auth_groups        = [authentik_group.media.id]
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   client_id          = module.secret_romm.fields["OIDC_CLIENT_ID"]
#   client_secret      = module.secret_romm.fields["OIDC_CLIENT_SECRET"]
#   redirect_uris      = ["https://romm.${var.cluster_domain}/api/oauth/openid"]
# }
