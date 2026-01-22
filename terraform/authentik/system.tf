data "authentik_certificate_key_pair" "generated" {
  name = "authentik Self-signed Certificate"
}

resource "authentik_system_settings" "settings" {
  avatars                      = "initials"
  default_token_duration       = "hours=1"
  default_user_change_email    = false
  default_user_change_username = false
  gdpr_compliance              = true
  impersonation                = true
  event_retention              = "days=365"

  footer_links = [
    {
      name = "Contact"
      href = "mailto:admin@vzkn.eu"
    }
  ]
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
  branding_title   = "Vzkn.eu"
  branding_logo    = "/static/dist/assets/icons/icon_left_brand.svg"
  branding_favicon = "/static/dist/assets/icons/icon.png"

  flow_authentication = authentik_flow.authentication.uuid
  flow_invalidation   = authentik_flow.invalidation.uuid
  flow_recovery       = authentik_flow.recovery.uuid
  flow_user_settings  = authentik_flow.user-settings.uuid
  flow_device_code    = authentik_flow.device-code.uuid
  flow_unenrollment   = authentik_flow.unenrollment.uuid
}

resource "authentik_service_connection_kubernetes" "local" {
  name  = "local"
  local = true
}

## LDAP Provider
resource "authentik_provider_ldap" "ldap" {
  name              = "LDAP"
  base_dn           = "dc=ldap,dc=${replace(var.cluster_domain, ".", ",dc=")}"
  bind_flow         = authentik_flow.ldap-authentication.uuid  # Simple flow without captcha
  unbind_flow       = authentik_flow.invalidation.uuid
  certificate       = data.authentik_certificate_key_pair.generated.id
  tls_server_name   = "ldap.${var.cluster_domain}"
  uid_start_number  = 10000
  gid_start_number  = 10000
  mfa_support       = false  # Disabled for service accounts
}

resource "authentik_application" "ldap" {
  name              = "LDAP"
  slug              = "ldap"
  group             = "Infrastructure"
  protocol_provider = authentik_provider_ldap.ldap.id
  meta_icon         = "fa://fa-address-book"
  meta_description  = "LDAP Directory"
  meta_launch_url   = "blank://blank"
  open_in_new_tab   = false
}

resource "authentik_policy_binding" "ldap" {
  target = authentik_application.ldap.uuid
  group  = authentik_group.users.id
  order  = 0
}

resource "authentik_outpost" "ldap" {
  name               = "ldap-outpost"
  type               = "ldap"
  service_connection = authentik_service_connection_kubernetes.local.id
  protocol_providers = [authentik_provider_ldap.ldap.id]
  config = jsonencode({
    authentik_host          = "https://sso.${var.cluster_domain}"
    authentik_host_insecure = false
    log_level               = "info"
    object_naming_template  = "ak-outpost-%(name)s"
    kubernetes_replicas     = 1
    kubernetes_namespace    = "security"
    kubernetes_service_type = "ClusterIP"
  })
}

# ## Proxy Outpost - DISABLED: Envoy Gateway ext-auth issue (Location header not forwarded)
# resource "authentik_outpost" "proxyoutpost" {
#   name               = "proxy-outpost"
#   type               = "proxy"
#   service_connection = authentik_service_connection_kubernetes.local.id
#   protocol_providers = [
#     # Media
#     module.proxy-navidrome.id,
#     module.proxy-jellystat.id,
#     # Home
#     module.proxy-zigbee.id,
#     module.proxy-searxng.id,
#     # module.proxy-screego.id,
#     # Downloads
#     module.proxy-qbittorrent.id,
#     # module.proxy-slskd.id,
#     module.proxy-metube.id,
#     module.proxy-dispatcharr.id,
#     module.proxy-prowlarr.id,
#     module.proxy-radarr.id,
#     module.proxy-sonarr.id,
#     # module.proxy-lidarr.id,
#     module.proxy-bazarr.id,
#     # Infrastructure
#     module.proxy-prometheus.id,
#     module.proxy-alertmanager.id,
#     module.proxy-victoria-logs.id,
#     module.proxy-karma.id,
#     module.proxy-kopia.id,
#   ]
#   config = jsonencode({
#     authentik_host          = "https://sso.${var.cluster_domain}",
#     log_level               = "warning",
#     object_naming_template  = "ak-outpost-%(name)s",
#     kubernetes_replicas     = 1,
#     kubernetes_namespace    = "security",
#     kubernetes_httproute_parent_refs = [
#       {
#         group       = "gateway.networking.k8s.io"
#         kind        = "Gateway"
#         name        = "envoy-internal"
#         namespace   = "network"
#         sectionName = "https"
#       },
#       {
#         group       = "gateway.networking.k8s.io"
#         kind        = "Gateway"
#         name        = "envoy-external"
#         namespace   = "network"
#         sectionName = "https"
#       }
#     ],
#     kubernetes_httproute_annotations = {
#       "gatus.home-operations.com/enabled" = "false"
#     }
#     kubernetes_service_type        = "ClusterIP",
#     kubernetes_disabled_components = ["ingress"],
#   })
# }
