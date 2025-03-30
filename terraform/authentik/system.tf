data "authentik_certificate_key_pair" "generated" {
  name = "authentik Self-signed Certificate"
}

data "authentik_brand" "authentik-default" {
  domain = "authentik-default"
}

# Get the default flows
data "authentik_flow" "default-brand-authentication" {
  slug = "default-authentication-flow"
}

data "authentik_flow" "default-brand-invalidation" {
  slug = "default-invalidation-flow"
}

data "authentik_flow" "default-brand-user-settings" {
  slug = "default-user-settings-flow"
}

import {
  to = authentik_brand.default
  id = data.authentik_brand.authentik-default.id
}

# Create/manage the default brand
resource "authentik_brand" "default" {
  domain           = "authentik-default"
  default          = false
  branding_title   = "authentik"
  branding_logo    = "/static/dist/assets/icons/icon_left_brand.svg"
  branding_favicon = "/static/dist/assets/icons/icon.png"

  flow_authentication = data.authentik_flow.default-brand-authentication.id
  flow_invalidation   = data.authentik_flow.default-brand-invalidation.id
  flow_user_settings  = data.authentik_flow.default-brand-user-settings.id
}

resource "authentik_brand" "home" {
  domain           = var.cluster_domain
  default          = true
  branding_title   = "Home"
  branding_logo    = "/static/dist/assets/icons/icon_left_brand.svg"
  branding_favicon = "/static/dist/assets/icons/icon.png"

  flow_authentication = authentik_flow.authentication.uuid
  flow_invalidation   = authentik_flow.invalidation.uuid
  flow_user_settings  = authentik_flow.user-settings.uuid
}

resource "authentik_service_connection_kubernetes" "local" {
  name  = "local"
  local = true
}

resource "authentik_outpost" "proxyoutpost" {
  name               = "proxy-outpost"
  type               = "proxy"
  service_connection = authentik_service_connection_kubernetes.local.id
  protocol_providers = [
    module.proxy-prowlarr.id,
    module.proxy-radarr.id,
    module.proxy-sonarr.id,
    # module.proxy-lidarr.id,
    module.proxy-bazarr.id
    # module.proxy-navidrome.id,
    # module.proxy-homepage.id
  ]
  config = jsonencode({
    authentik_host          = "https://sso.${var.cluster_domain}",
    authentik_host_insecure = false,
    authentik_host_browser  = "",
    log_level               = "debug",
    object_naming_template  = "ak-outpost-%(name)s",
    docker_network          = null,
    docker_map_ports        = true,
    docker_labels           = null,
    container_image         = null,
    kubernetes_replicas     = 1,
    kubernetes_namespace    = "security",
    kubernetes_ingress_annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-production"
    },
    kubernetes_ingress_secret_name = "proxy-outpost-tls",
    kubernetes_service_type        = "ClusterIP",
    kubernetes_disabled_components = [],
    kubernetes_image_pull_secrets  = []
  })
}
