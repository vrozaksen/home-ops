# ═══════════════════════════════════════════════════════════════════════════════
# Authentik Applications Configuration
# ═══════════════════════════════════════════════════════════════════════════════
#
# Sections organized by Authentik dashboard groups:
#   - Media (ff + admin)
#   - Home (users/household + admin)
#   - Development (users + admin)
#   - Downloads (admin)
#   - Infrastructure (admin, Gatus=PUBLIC)
#
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────────
# Locals - OAuth2 secrets from Bitwarden
# ─────────────────────────────────────────────────────────────────────────────────

locals {
  oauth_apps = [
    # Active
    "flux",
    "forgejo",
    "grafana",
    "headlamp",
    "nextcloud",
    "pgadmin",
    "qui",
    "rxresume",
    "unraid",
    # Disabled
    # "coder",
    # "harbor",
    # "karakeep",
    # "miniflux",
    # "open-webui",
    # "paperless",
  ]
}

data "bitwarden_secret" "application" {
  for_each = toset(local.oauth_apps)
  key      = each.key
}

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

# ═══════════════════════════════════════════════════════════════════════════════
# MEDIA (ff + admin)
# Namespace: media
# ═══════════════════════════════════════════════════════════════════════════════

# Emby uses LDAP authentication - launch link only
resource "authentik_application" "emby" {
  name             = "Emby"
  slug             = "emby"
  group            = "Media"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/emby.png"
  meta_description = "Media server"
  meta_launch_url  = "https://emby.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "emby" {
  for_each = { for idx, group in [authentik_group.ff.id, authentik_group.admin.id] : idx => group }
  target   = authentik_application.emby.uuid
  group    = each.value
  order    = each.key
}

# Seerr uses Emby/Plex authentication - launch link only
resource "authentik_application" "seerr" {
  name             = "Seerr"
  slug             = "seerr"
  group            = "Media"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/overseerr.png"
  meta_description = "Media requests"
  meta_launch_url  = "https://seerr.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "seerr" {
  for_each = { for idx, group in [authentik_group.ff.id, authentik_group.admin.id] : idx => group }
  target   = authentik_application.seerr.uuid
  group    = each.value
  order    = each.key
}

# DISABLED: Envoy Gateway ext-auth issue - converted to launch URLs
# module "proxy-navidrome" {
#   source             = "./proxy_application"
#   name               = "Navidrome"
#   description        = "Music streaming"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/navidrome.png"
#   group              = "Media"
#   slug               = "music"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.ff.id, authentik_group.admin.id]
#   ignore_paths       = "^/rest/.*$|^/share/.*$"
# }

resource "authentik_application" "navidrome" {
  name             = "Navidrome"
  slug             = "music"
  group            = "Media"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/navidrome.png"
  meta_description = "Music streaming"
  meta_launch_url  = "https://music.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "navidrome" {
  for_each = { for idx, group in [authentik_group.ff.id, authentik_group.admin.id] : idx => group }
  target   = authentik_application.navidrome.uuid
  group    = each.value
  order    = each.key
}

# module "proxy-jellystat" {
#   source             = "./proxy_application"
#   name               = "Jellystat"
#   description        = "Media statistics"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/jellystat.png"
#   group              = "Media"
#   slug               = "jellystat"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

resource "authentik_application" "jellystat" {
  name             = "Jellystat"
  slug             = "jellystat"
  group            = "Media"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/jellystat.png"
  meta_description = "Media statistics"
  meta_launch_url  = "https://jellystat.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "jellystat" {
  target = authentik_application.jellystat.uuid
  group  = authentik_group.admin.id
  order  = 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# HOME (users/household + admin)
# Namespaces: home-automation, self-hosted
# ═══════════════════════════════════════════════════════════════════════════════

# Home Assistant has its own authentication - launch link only
resource "authentik_application" "home-assistant" {
  name             = "Home Assistant"
  slug             = "home-assistant"
  group            = "Home"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/home-assistant.png"
  meta_description = "Smart home control"
  meta_launch_url  = "https://hass.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "home-assistant" {
  for_each = { for idx, group in [authentik_group.household.id, authentik_group.admin.id] : idx => group }
  target   = authentik_application.home-assistant.uuid
  group    = each.value
  order    = each.key
}

# module "proxy-zigbee" {
#   source             = "./proxy_application"
#   name               = "Zigbee2MQTT"
#   description        = "Zigbee device management"
#   icon_url           = "https://raw.githubusercontent.com/Koenkk/zigbee2mqtt/master/images/logo.png"
#   group              = "Home"
#   slug               = "zigbee"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.household.id, authentik_group.admin.id]
# }

resource "authentik_application" "zigbee" {
  name             = "Zigbee2MQTT"
  slug             = "zigbee"
  group            = "Home"
  meta_icon        = "https://raw.githubusercontent.com/Koenkk/zigbee2mqtt/master/images/logo.png"
  meta_description = "Zigbee device management"
  meta_launch_url  = "https://zigbee.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "zigbee" {
  for_each = { for idx, group in [authentik_group.household.id, authentik_group.admin.id] : idx => group }
  target   = authentik_application.zigbee.uuid
  group    = each.value
  order    = each.key
}

# module "proxy-searxng" {
#   source             = "./proxy_application"
#   name               = "SearXNG"
#   description        = "Private search engine"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/searxng.png"
#   group              = "Home"
#   slug               = "search"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.ff.id, authentik_group.admin.id]
# }

resource "authentik_application" "searxng" {
  name             = "SearXNG"
  slug             = "search"
  group            = "Home"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/searxng.png"
  meta_description = "Private search engine"
  meta_launch_url  = "https://search.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "searxng" {
  for_each = { for idx, group in [authentik_group.ff.id, authentik_group.admin.id] : idx => group }
  target   = authentik_application.searxng.uuid
  group    = each.value
  order    = each.key
}

# module "proxy-screego" {
#   source             = "./proxy_application"
#   name               = "Screego"
#   description        = "Screen sharing"
#   icon_url           = "https://screego.net/logo.svg"
#   group              = "Home"
#   slug               = "screego"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.users.id]
# }

# module "proxy-bambu-studio" {
#   source             = "./proxy_application"
#   name               = "Bambu Studio"
#   description        = "3D printing slicer"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/bambu-studio.png"
#   group              = "Home"
#   slug               = "bambu-studio"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.household.id, authentik_group.admin.id]
# }
#
# module "proxy-bambu-storage" {
#   source             = "./proxy_application"
#   name               = "Bambu Storage"
#   description        = "3D model storage"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/bambu-studio.png"
#   group              = "Home"
#   slug               = "bambu-storage"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.household.id, authentik_group.admin.id]
# }

module "oauth2-nextcloud" {
  source             = "./oauth2_application"
  name               = "Nextcloud"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/nextcloud.png"
  launch_url         = "https://cloud.${var.cluster_domain}"
  description        = "Cloud storage & collaboration"
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.users.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["nextcloud"].client_id
  client_secret      = local.parsed_secrets["nextcloud"].client_secret
  redirect_uris      = ["https://cloud.${var.cluster_domain}/apps/user_oidc/code"]
}

module "oauth2-rxresume" {
  source             = "./oauth2_application"
  name               = "Reactive Resume"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/reactive-resume.png"
  launch_url         = "https://rxresume.${var.cluster_domain}/auth/login"
  description        = "Resume builder"
  newtab             = true
  group              = "Home"
  auth_groups        = [authentik_group.users.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["rxresume"].client_id
  client_secret      = local.parsed_secrets["rxresume"].client_secret
  redirect_uris      = ["https://rxresume.${var.cluster_domain}/api/auth/oauth2/callback/custom"]
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEVELOPMENT (users + admin)
# Namespace: development, self-hosted
# ═══════════════════════════════════════════════════════════════════════════════

module "oauth2-forgejo" {
  source             = "./oauth2_application"
  name               = "Forgejo"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/forgejo.png"
  launch_url         = "https://forgejo.${var.cluster_domain}"
  description        = "Git forge"
  newtab             = true
  group              = "Development"
  auth_groups        = [authentik_group.users.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["forgejo"].client_id
  client_secret      = local.parsed_secrets["forgejo"].client_secret
  redirect_uris      = ["https://forgejo.${var.cluster_domain}/user/oauth2/Authentik/callback"]
}

# module "oauth2-harbor" {
#   source                       = "./oauth2_application"
#   name                         = "Harbor"
#   icon_url                     = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/harbor.png"
#   launch_url                   = "https://harbor.${var.cluster_domain}"
#   description                  = "Container registry"
#   newtab                       = true
#   group                        = "Development"
#   auth_groups                  = [authentik_group.users.id]
#   authorization_flow           = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow            = resource.authentik_flow.provider-invalidation.uuid
#   client_id                    = local.parsed_secrets["harbor"].client_id
#   client_secret                = local.parsed_secrets["harbor"].client_secret
#   additional_property_mappings = [authentik_property_mapping_provider_scope.groups.id]
#   redirect_uris                = ["https://harbor.${var.cluster_domain}/c/oidc/callback"]
# }

# IT-Tools - PUBLIC (no group restrictions)
resource "authentik_application" "it-tools" {
  name             = "IT Tools"
  slug             = "it-tools"
  group            = "Development"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/it-tools.png"
  meta_description = "Developer utilities"
  meta_launch_url  = "https://it-tools.${var.cluster_domain}"
  open_in_new_tab  = true
}
# No policy binding = accessible to everyone

# ═══════════════════════════════════════════════════════════════════════════════
# DOWNLOADS (admin only)
# Namespace: downloads
# ═══════════════════════════════════════════════════════════════════════════════

module "oauth2-qui" {
  source             = "./oauth2_application"
  name               = "Qui"
  description        = "Queue UI"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/qui.png"
  launch_url         = "https://qui.${var.cluster_domain}"
  newtab             = true
  group              = "Downloads"
  auth_groups        = [authentik_group.admin.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["qui"].client_id
  client_secret      = local.parsed_secrets["qui"].client_secret
  redirect_uris      = ["https://qui.${var.cluster_domain}/api/auth/oidc/callback"]
}

# DISABLED: Envoy Gateway ext-auth issue - converted to launch URLs
# module "proxy-qbittorrent" {
#   source             = "./proxy_application"
#   name               = "qBittorrent"
#   description        = "Torrent client"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/qbittorrent.png"
#   group              = "Downloads"
#   slug               = "qb"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

resource "authentik_application" "qbittorrent" {
  name             = "qBittorrent"
  slug             = "qb"
  group            = "Downloads"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/qbittorrent.png"
  meta_description = "Torrent client"
  meta_launch_url  = "https://qb.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "qbittorrent" {
  target = authentik_application.qbittorrent.uuid
  group  = authentik_group.admin.id
  order  = 0
}

# module "proxy-slskd" {
#   source             = "./proxy_application"
#   name               = "slskd"
#   description        = "Soulseek client"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/slskd.png"
#   group              = "Downloads"
#   slug               = "slskd"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

# module "proxy-metube" {
#   source             = "./proxy_application"
#   name               = "MeTube"
#   description        = "YouTube downloader"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/metube.png"
#   group              = "Downloads"
#   slug               = "metube"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

resource "authentik_application" "metube" {
  name             = "MeTube"
  slug             = "metube"
  group            = "Downloads"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/metube.png"
  meta_description = "YouTube downloader"
  meta_launch_url  = "https://metube.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "metube" {
  target = authentik_application.metube.uuid
  group  = authentik_group.admin.id
  order  = 0
}

# module "proxy-dispatcharr" {
#   source             = "./proxy_application"
#   name               = "Dispatcharr"
#   description        = "Download dispatcher"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/dispatcharr.png"
#   group              = "Downloads"
#   slug               = "dispatcharr"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

resource "authentik_application" "dispatcharr" {
  name             = "Dispatcharr"
  slug             = "dispatcharr"
  group            = "Downloads"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/dispatcharr.png"
  meta_description = "Download dispatcher"
  meta_launch_url  = "https://dispatcharr.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "dispatcharr" {
  target = authentik_application.dispatcharr.uuid
  group  = authentik_group.admin.id
  order  = 0
}

# module "proxy-prowlarr" {
#   source             = "./proxy_application"
#   name               = "Prowlarr"
#   description        = "Torrent indexer"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/prowlarr.png"
#   group              = "Downloads"
#   slug               = "prowlarr"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

resource "authentik_application" "prowlarr" {
  name             = "Prowlarr"
  slug             = "prowlarr"
  group            = "Downloads"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/prowlarr.png"
  meta_description = "Torrent indexer"
  meta_launch_url  = "https://prowlarr.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "prowlarr" {
  target = authentik_application.prowlarr.uuid
  group  = authentik_group.admin.id
  order  = 0
}

# module "proxy-radarr" {
#   source             = "./proxy_application"
#   name               = "Radarr"
#   description        = "Movies"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/radarr.png"
#   group              = "Downloads"
#   slug               = "radarr"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

resource "authentik_application" "radarr" {
  name             = "Radarr"
  slug             = "radarr"
  group            = "Downloads"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/radarr.png"
  meta_description = "Movies"
  meta_launch_url  = "https://radarr.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "radarr" {
  target = authentik_application.radarr.uuid
  group  = authentik_group.admin.id
  order  = 0
}

# module "proxy-sonarr" {
#   source             = "./proxy_application"
#   name               = "Sonarr"
#   description        = "TV Shows"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/sonarr.png"
#   group              = "Downloads"
#   slug               = "sonarr"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

resource "authentik_application" "sonarr" {
  name             = "Sonarr"
  slug             = "sonarr"
  group            = "Downloads"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/sonarr.png"
  meta_description = "TV Shows"
  meta_launch_url  = "https://sonarr.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "sonarr" {
  target = authentik_application.sonarr.uuid
  group  = authentik_group.admin.id
  order  = 0
}

# module "proxy-lidarr" {
#   source             = "./proxy_application"
#   name               = "Lidarr"
#   description        = "Music"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/lidarr.png"
#   group              = "Downloads"
#   slug               = "lidarr"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

# module "proxy-bazarr" {
#   source             = "./proxy_application"
#   name               = "Bazarr"
#   description        = "Subtitles"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/bazarr.png"
#   group              = "Downloads"
#   slug               = "bazarr"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

resource "authentik_application" "bazarr" {
  name             = "Bazarr"
  slug             = "bazarr"
  group            = "Downloads"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/bazarr.png"
  meta_description = "Subtitles"
  meta_launch_url  = "https://bazarr.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "bazarr" {
  target = authentik_application.bazarr.uuid
  group  = authentik_group.admin.id
  order  = 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# INFRASTRUCTURE (admin, Gatus=PUBLIC)
# Namespaces: observability, flux-system, database, storage, rook-ceph, external
# ═══════════════════════════════════════════════════════════════════════════════

# Gatus - PUBLIC (no group restrictions)
resource "authentik_application" "gatus" {
  name             = "Gatus"
  slug             = "gatus"
  group            = "Infrastructure"
  meta_icon        = "https://raw.githubusercontent.com/TwiN/gatus/master/.github/assets/logo.png"
  meta_description = "Status page"
  meta_launch_url  = "https://gatus.${var.cluster_domain}"
  open_in_new_tab  = true
}
# No policy binding = accessible to everyone

module "oauth2-grafana" {
  source             = "./oauth2_application"
  name               = "Grafana"
  icon_url           = "https://raw.githubusercontent.com/grafana/grafana/main/public/img/icons/mono/grafana.svg"
  launch_url         = "https://grafana.${var.cluster_domain}"
  description        = "Observability dashboards"
  newtab             = true
  group              = "Infrastructure"
  auth_groups        = [authentik_group.admin.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["grafana"].client_id
  client_secret      = local.parsed_secrets["grafana"].client_secret
  redirect_uris      = ["https://grafana.${var.cluster_domain}/login/generic_oauth"]
}

# module "proxy-prometheus" {
#   source             = "./proxy_application"
#   name               = "Prometheus"
#   description        = "Metrics"
#   icon_url           = "https://raw.githubusercontent.com/prometheus/prometheus/main/documentation/images/prometheus-logo.svg"
#   group              = "Infrastructure"
#   slug               = "prometheus"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

resource "authentik_application" "prometheus" {
  name             = "Prometheus"
  slug             = "prometheus"
  group            = "Infrastructure"
  meta_icon        = "https://raw.githubusercontent.com/prometheus/prometheus/main/documentation/images/prometheus-logo.svg"
  meta_description = "Metrics"
  meta_launch_url  = "https://prometheus.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "prometheus" {
  target = authentik_application.prometheus.uuid
  group  = authentik_group.admin.id
  order  = 0
}

# module "proxy-alertmanager" {
#   source             = "./proxy_application"
#   name               = "Alertmanager"
#   description        = "Alert management"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/alertmanager.png"
#   group              = "Infrastructure"
#   slug               = "alertmanager"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

resource "authentik_application" "alertmanager" {
  name             = "Alertmanager"
  slug             = "alertmanager"
  group            = "Infrastructure"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/alertmanager.png"
  meta_description = "Alert management"
  meta_launch_url  = "https://alertmanager.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "alertmanager" {
  target = authentik_application.alertmanager.uuid
  group  = authentik_group.admin.id
  order  = 0
}

# module "proxy-victoria-logs" {
#   source             = "./proxy_application"
#   name               = "Victoria Logs"
#   description        = "Log aggregation"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/victoriametrics.png"
#   group              = "Infrastructure"
#   slug               = "logs"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

resource "authentik_application" "victoria-logs" {
  name             = "Victoria Logs"
  slug             = "logs"
  group            = "Infrastructure"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/victoriametrics.png"
  meta_description = "Log aggregation"
  meta_launch_url  = "https://logs.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "victoria-logs" {
  target = authentik_application.victoria-logs.uuid
  group  = authentik_group.admin.id
  order  = 0
}

# module "proxy-karma" {
#   source             = "./proxy_application"
#   name               = "Karma"
#   description        = "Alert dashboard"
#   icon_url           = "https://raw.githubusercontent.com/prymitive/karma/main/ui/public/favicon.ico"
#   group              = "Infrastructure"
#   slug               = "karma"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

resource "authentik_application" "karma" {
  name             = "Karma"
  slug             = "karma"
  group            = "Infrastructure"
  meta_icon        = "https://raw.githubusercontent.com/prymitive/karma/main/ui/public/favicon.ico"
  meta_description = "Alert dashboard"
  meta_launch_url  = "https://karma.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "karma" {
  target = authentik_application.karma.uuid
  group  = authentik_group.admin.id
  order  = 0
}

module "oauth2-headlamp" {
  source             = "./oauth2_application"
  name               = "Headlamp"
  icon_url           = "https://raw.githubusercontent.com/headlamp-k8s/headlamp/refs/heads/main/frontend/src/resources/icon-dark.svg"
  launch_url         = "https://headlamp.${var.cluster_domain}"
  description        = "Kubernetes dashboard"
  newtab             = true
  group              = "Infrastructure"
  auth_groups        = [authentik_group.admin.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["headlamp"].client_id
  client_secret      = local.parsed_secrets["headlamp"].client_secret
  redirect_uris      = ["https://headlamp.${var.cluster_domain}/oidc-callback"]
  # Include groups claim for K8s OIDC authentication
  additional_property_mappings = [authentik_property_mapping_provider_scope.groups.id]
}

module "oauth2-flux" {
  source             = "./oauth2_application"
  name               = "Flux"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/flux-cd.png"
  launch_url         = "https://flux.${var.cluster_domain}"
  description        = "GitOps status"
  newtab             = true
  group              = "Infrastructure"
  auth_groups        = [authentik_group.admin.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["flux"].client_id
  client_secret      = local.parsed_secrets["flux"].client_secret
  redirect_uris      = ["https://flux.${var.cluster_domain}/oauth2/callback"]
}

module "oauth2-pgadmin" {
  source             = "./oauth2_application"
  name               = "PgAdmin"
  icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/pgadmin.png"
  launch_url         = "https://pgadmin.${var.cluster_domain}"
  description        = "PostgreSQL management"
  newtab             = true
  group              = "Infrastructure"
  auth_groups        = [authentik_group.admin.id]
  authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
  client_id          = local.parsed_secrets["pgadmin"].client_id
  client_secret      = local.parsed_secrets["pgadmin"].client_secret
  redirect_uris      = ["https://pgadmin.${var.cluster_domain}/oauth2/authorize"]
}

# module "proxy-kopia" {
#   source             = "./proxy_application"
#   name               = "Kopia"
#   description        = "Backup management"
#   icon_url           = "https://raw.githubusercontent.com/kopia/kopia/master/icons/kopia.svg"
#   group              = "Infrastructure"
#   slug               = "kopia"
#   domain             = var.cluster_domain
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   auth_groups        = [authentik_group.admin.id]
# }

resource "authentik_application" "kopia" {
  name             = "Kopia"
  slug             = "kopia"
  group            = "Infrastructure"
  meta_icon        = "https://raw.githubusercontent.com/kopia/kopia/master/icons/kopia.svg"
  meta_description = "Backup management"
  meta_launch_url  = "https://kopia.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "kopia" {
  target = authentik_application.kopia.uuid
  group  = authentik_group.admin.id
  order  = 0
}

# Ceph Dashboard uses native auth - launch link only
resource "authentik_application" "ceph" {
  name             = "Ceph Dashboard"
  slug             = "ceph"
  group            = "Infrastructure"
  meta_icon        = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/ceph.png"
  meta_description = "Storage cluster"
  meta_launch_url  = "https://ceph.${var.cluster_domain}"
  open_in_new_tab  = true
}

resource "authentik_policy_binding" "ceph" {
  target = authentik_application.ceph.uuid
  group  = authentik_group.admin.id
  order  = 0
}

module "oauth2-unraid" {
  source                       = "./oauth2_application"
  name                         = "UnRaid"
  icon_url                     = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/unraid.png"
  launch_url                   = "https://aincrad.home.${var.cluster_domain}:4443"
  description                  = "NAS"
  newtab                       = true
  group                        = "Infrastructure"
  auth_groups                  = [authentik_group.admin.id]
  authorization_flow           = resource.authentik_flow.provider-authorization-implicit-consent.uuid
  invalidation_flow            = resource.authentik_flow.provider-invalidation.uuid
  client_id                    = local.parsed_secrets["unraid"].client_id
  client_secret                = local.parsed_secrets["unraid"].client_secret
  additional_property_mappings = [authentik_property_mapping_provider_scope.groups.id]
  redirect_uris                = ["https://aincrad.home.${var.cluster_domain}:4443/graphql/api/auth/oidc/callback"]
}

# ═══════════════════════════════════════════════════════════════════════════════
# SENTRY (SAML - manually configured)
# Namespace: sentry
# ═══════════════════════════════════════════════════════════════════════════════

# Sentry uses SAML authentication configured manually in Sentry UI
# Uncomment and configure when ready to manage via Terraform
#
# resource "authentik_provider_saml" "sentry" {
#   name               = "Sentry"
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   acs_url            = "https://sentry.${var.cluster_domain}/saml/acs/<org-slug>/"
#   issuer             = "https://sso.${var.cluster_domain}"
#   sp_binding         = "post"
#   audience           = "https://sentry.${var.cluster_domain}/saml/metadata/<org-slug>/"
#   signing_kp         = data.authentik_certificate_key_pair.generated.id
# }
#
# resource "authentik_application" "sentry" {
#   name              = "Sentry"
#   slug              = "sentry"
#   group             = "Infrastructure"
#   protocol_provider = authentik_provider_saml.sentry.id
#   meta_icon         = "https://raw.githubusercontent.com/getsentry/sentry/master/src/sentry/static/sentry/images/favicon.ico"
#   meta_description  = "Error tracking"
#   meta_launch_url   = "https://sentry.${var.cluster_domain}"
#   open_in_new_tab   = true
# }
#
# resource "authentik_policy_binding" "sentry" {
#   target = authentik_application.sentry.uuid
#   group  = authentik_group.admin.id
#   order  = 0
# }

# ═══════════════════════════════════════════════════════════════════════════════
# DISABLED APPLICATIONS (commented for future use)
# ═══════════════════════════════════════════════════════════════════════════════

# module "oauth2-coder" {
#   source             = "./oauth2_application"
#   name               = "Coder"
#   icon_url           = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/refs/heads/main/png/coder.png"
#   launch_url         = "https://coder.${var.cluster_domain}"
#   description        = "Cloud development environments"
#   newtab             = true
#   group              = "Development"
#   auth_groups        = [authentik_group.admin.id]
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   client_id          = local.parsed_secrets["coder"].client_id
#   client_secret      = local.parsed_secrets["coder"].client_secret
#   redirect_uris      = ["https://coder.${var.cluster_domain}/api/v2/users/oidc/callback"]
# }

# module "oauth2-karakeep" {
#   source             = "./oauth2_application"
#   name               = "Karakeep"
#   icon_url           = "https://raw.githubusercontent.com/karakeep-app/karakeep/refs/heads/main/docs/static/img/logo.png"
#   launch_url         = "https://karakeep.${var.cluster_domain}"
#   description        = "Bookmark manager"
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
#   description        = "RSS reader"
#   newtab             = true
#   group              = "Home"
#   auth_groups        = [authentik_group.users.id]
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   client_id          = local.parsed_secrets["miniflux"].client_id
#   client_secret      = local.parsed_secrets["miniflux"].client_secret
#   redirect_uris      = ["https://miniflux.${var.cluster_domain}/oauth2/oidc/callback"]
# }

# module "oauth2-paperless" {
#   source             = "./oauth2_application"
#   name               = "Paperless"
#   icon_url           = "https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/dev/resources/logo/web/svg/Color%20logo%20-%20no%20background.svg"
#   launch_url         = "https://docs.${var.cluster_domain}"
#   description        = "Document management"
#   newtab             = true
#   group              = "Home"
#   auth_groups        = [authentik_group.users.id]
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   client_id          = local.parsed_secrets["paperless"].client_id
#   client_secret      = local.parsed_secrets["paperless"].client_secret
#   redirect_uris      = ["https://docs.${var.cluster_domain}/accounts/oidc/authentik/login/callback/"]
# }

# module "oauth2-open-webui" {
#   source             = "./oauth2_application"
#   name               = "Open WebUI"
#   icon_url           = "https://raw.githubusercontent.com/open-webui/open-webui/refs/heads/main/static/favicon.png"
#   launch_url         = "https://chat.${var.cluster_domain}/auth"
#   description        = "AI chat interface"
#   newtab             = true
#   group              = "Home"
#   auth_groups        = [authentik_group.users.id]
#   authorization_flow = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   invalidation_flow  = resource.authentik_flow.provider-invalidation.uuid
#   client_id          = local.parsed_secrets["open-webui"].client_id
#   client_secret      = local.parsed_secrets["open-webui"].client_secret
#   redirect_uris      = ["https://chat.${var.cluster_domain}/oauth/oidc/callback"]
# }
