locals {
  oauth_apps = [
    "autobrr",
    "dashbrr",
    "grafana",
    "headlamp",
    "kyoo",
    "mealie",
    "miniflux",
    "ocis",
    "outline",
    "paperless",
    "pgadmin",
    "rresume",
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

# module "proxy-homepage" {
#   source             = "./proxy_application"
#   name               = "Home"
#   description        = "Homepage"
#   icon_url           = "https://raw.githubusercontent.com/gethomepage/homepage/main/public/android-chrome-192x192.png"
#   group              = "Selfhosted"
#   slug               = "home"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.users.id]
# }


## Media
module "oauth2-autobrr" {
  source             = "./oauth2_application"
  name               = "Autobrr"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/autobrr.png"
  launch_url         = "https://autobrr.${var.cluster_domain}/api/auth/oidc/callback"
  description        = "Downloads tooling" # TODO
  newtab             = true
  group              = "Downloads"
  auth_groups        = [authentik_group.media.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["autobrr"].client_id
  client_secret      = local.parsed_secrets["autobrr"].client_secret
  redirect_uris      = ["https://autobrr.${var.cluster_domain}/api/auth/oidc/callback"]
}

module "oauth2-dashbrr" {
  source             = "./oauth2_application"
  name               = "Dashbrr"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/autobrr.png"
  launch_url         = "https://dashbrr.${var.cluster_domain}/api/auth/oidc/callback"
  description        = "Downloads tooling" # TODO
  newtab             = true
  group              = "Downloads"
  auth_groups        = [authentik_group.media.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["dashbrr"].client_id
  client_secret      = local.parsed_secrets["dashbrr"].client_secret
  redirect_uris      = ["https://dashbrr.${var.cluster_domain}/api/auth/oidc/callback"]
}

## Infrastructure
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
module "oauth2-kyoo" {
  source             = "./oauth2_application"
  name               = "Kyoo"
  icon_url           = "https://raw.githubusercontent.com/zoriya/Kyoo/master/icons/icon-256x256.png"
  launch_url         = "https://kyoo.${var.cluster_domain}/api/auth/login/authentik?redirectUrl=https://kyoo.${var.cluster_domain}/login/callback"
  description        = "Media Player"
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.media.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["kyoo"].client_id
  client_secret      = local.parsed_secrets["kyoo"].client_secret
  redirect_uris      = ["https://kyoo.${var.cluster_domain}/api/auth/logged/authentik"]
}

module "oauth2-ocis" {
  source             = "./oauth2_application"
  name               = "Owncloud"
  icon_url           = "https://raw.githubusercontent.com/owncloud/owncloud.github.io/main/static/favicon/favicon.png"
  launch_url         = "https://cloud.${var.cluster_domain}"
  description        = "Personal Cloud"
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.users.id]
  client_type        = "public"
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["ocis"].client_id
  # additional_property_mappings = formatlist(authentik_scope_mapping.openid-nextcloud.id)
  redirect_uris = [
    "https://cloud.${var.cluster_domain}",
    "https://cloud.${var.cluster_domain}/oidc-callback.html",
    "https://cloud.${var.cluster_domain}/oidc-silent-redirect.html"
  ]
}

module "oauth2-ocis-android" {
  source             = "./oauth2_application"
  name               = "Owncloud-android"
  launch_url         = "blank://blank"
  auth_groups        = [authentik_group.users.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = "e4rAsNUSIUs0lF4nbv9FmCeUkTlV9GdgTLDH1b5uie7syb90SzEVrbN7HIpmWJeD"
  client_secret      = "dInFYGV33xKzhbRmpqQltYNdfLdJIfJ9L5ISoKhNoT9qZftpdWSP71VrpGR9pmoD"
  redirect_uris      = ["oc://android.owncloud.com"]
}

module "oauth2-ocis-desktop" {
  source             = "./oauth2_application"
  name               = "Owncloud-desktop"
  launch_url         = "blank://blank"
  auth_groups        = [authentik_group.users.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = "xdXOt13JKxym1B1QcEncf2XDkLAexMBFwiT9j6EfhhHFJhs2KM9jbjTmf8JBXE69"
  client_secret      = "UBntmLjC2yYCeHwsyj73Uwo9TAaecAetRwMw0xYcvNL9yRdLSUi0hUAHfvCHFeFh"
  redirect_uris = [
    { matching_mode = "regex", url = "http://127.0.0.1(:.*)?" },
    { matching_mode = "regex", url = "http://localhost(:.*)?" }
  ]
}

module "oauth2-ocis-ios" {
  source             = "./oauth2_application"
  name               = "Owncloud-ios"
  launch_url         = "blank://blank"
  auth_groups        = [authentik_group.users.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = "mxd5OQDk6es5LzOzRvidJNfXLUZS2oN3oUFeXPP8LpPrhx3UroJFduGEYIBOxkY1"
  client_secret      = "KFeFWWEZO9TkisIQzR3fo7hfiMXlOpaqP8CFuTbSHzV1TUuGECglPxpiVKJfOXIx"
  redirect_uris = [
    "oc://ios.owncloud.com",
    "oc.ios://ios.owncloud.com"
  ]
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

# module "oauth2-nextcloud" {
#   source                       = "./oauth2_application"
#   name                         = "Nextcloud"
#   icon_url                     = "https://upload.wikimedia.org/wikipedia/commons/6/60/Nextcloud_Logo.svg"
#   launch_url                   = "https://files.${var.cluster_domain}"
#   description                  = "Files"
#   newtab                       = true
#   group                        = "Selfhosted"
#   auth_groups                  = [authentik_group.media.id]
#   authorization_flow           = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow            = resource.authentik_flow.provider-invalidation.uuid
#   client_id                    = module.secret_nextcloud.fields["OIDC_CLIENT_ID"]
#   client_secret                = module.secret_nextcloud.fields["OIDC_CLIENT_SECRET"]
#   include_claims_in_id_token   = false
#   additional_property_mappings = formatlist(authentik_property_mapping_provider_scope.openid-nextcloud.id)
#   sub_mode                     = "user_username"
#   redirect_uris                = ["https://files.${module.secret_authentik.fields["CLUSTER_DOMAIN"]}/apps/oidc_login/oidc"]
# }

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
