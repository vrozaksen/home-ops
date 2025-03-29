data "bitwarden_secret" "ocis" {
  key = "ocis"
}

locals {
  ocis_secrets = {
    for line in split("\n", data.bitwarden_secret.ocis.value) :
    trimspace(split(":", line)[0]) => trimspace(substr(line, length(split(":", line)[0]) + 1, -1))
    if can(regex(":", line)) && trimspace(line) != ""
  }
}

resource "authentik_group" "ocis" {
  name         = "Ocis"
  is_superuser = false
}

## Web Client
resource "authentik_provider_oauth2" "ocis_web" {
  name                  = "ocis-web-provider"
  client_id             = local.ocis_secrets["OCIS_WEB_CLIENT_ID"]
  client_secret         = null
  authorization_flow    = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow   = authentik_flow.authentication.uuid
  invalidation_flow     = data.authentik_flow.default-provider-invalidation-flow.id
  property_mappings     = data.authentik_property_mapping_provider_scope.oauth2.ids
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id
  sub_mode              = "public"
  pkce_enabled          = true

  allowed_redirect_uris = [
    "https://cloud.${var.cluster_domain}/",
    "https://cloud.${var.cluster_domain}/oidc-callback.html",
    "https://cloud.${var.cluster_domain}/oidc-silent-redirect.html"
  ]
}

resource "authentik_application" "ocis_web" {
  name               = "ownCloud Web"
  slug               = "ocis-web"
  protocol_provider  = authentik_provider_oauth2.ocis_web.id
  group              = authentik_group.ocis.name
  meta_icon          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/owncloud.png"
  meta_launch_url    = "https://cloud.${var.cluster_domain}/"
  policy_engine_mode = "all"
  open_in_new_tab    = true
}

## Desktop Client
resource "authentik_provider_oauth2" "ocis_desktop" {
  name                  = "ocis-desktop-provider"
  client_id             = local.ocis_secrets["OCIS_DESKTOP_CLIENT_ID"]
  client_secret         = local.ocis_secrets["OCIS_DESKTOP_CLIENT_SECRET"]
  authorization_flow    = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow   = authentik_flow.authentication.uuid
  invalidation_flow     = data.authentik_flow.default-provider-invalidation-flow.id
  property_mappings     = data.authentik_property_mapping_provider_scope.oauth2.ids
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id
  sub_mode              = "hashed_user_id"
  pkce_enabled          = false

  allowed_redirect_uris = [
    "http://127.0.0.1(:.*)?",
    "http://localhost(:.*)?"
  ]
}

resource "authentik_application" "ocis_desktop" {
  name               = "ownCloud Desktop"
  slug               = "ocis-desktop"
  protocol_provider  = authentik_provider_oauth2.ocis_desktop.id
  group              = authentik_group.ocis.name
  meta_icon          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/owncloud.png"
  meta_launch_url    = "https://cloud.${var.cluster_domain}/"
  policy_engine_mode = "all"
  open_in_new_tab    = true
}

## Android Client
resource "authentik_provider_oauth2" "ocis_android" {
  name                  = "ocis-android-provider"
  client_id             = local.ocis_secrets["OCIS_ANDROID_CLIENT_ID"]
  client_secret         = local.ocis_secrets["OCIS_ANDROID_CLIENT_SECRET"]
  authorization_flow    = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow   = authentik_flow.authentication.uuid
  invalidation_flow     = data.authentik_flow.default-provider-invalidation-flow.id
  property_mappings     = data.authentik_property_mapping_provider_scope.oauth2.ids
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id
  sub_mode              = "hashed_user_id"
  pkce_enabled          = false

  allowed_redirect_uris = [
    "oc://android.owncloud.com"
  ]
}

resource "authentik_application" "ocis_android" {
  name               = "ownCloud Android"
  slug               = "ocis-android"
  protocol_provider  = authentik_provider_oauth2.ocis_android.id
  group              = authentik_group.ocis.name
  meta_icon          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/owncloud.png"
  meta_launch_url    = "https://cloud.${var.cluster_domain}/"
  policy_engine_mode = "all"
  open_in_new_tab    = true
}

## iOS Client
resource "authentik_provider_oauth2" "ocis_ios" {
  name                  = "ocis-ios-provider"
  client_id             = local.ocis_secrets["OCIS_IOS_CLIENT_ID"]
  client_secret         = local.ocis_secrets["OCIS_IOS_CLIENT_SECRET"]
  authorization_flow    = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow   = authentik_flow.authentication.uuid
  invalidation_flow     = data.authentik_flow.default-provider-invalidation-flow.id
  property_mappings     = data.authentik_property_mapping_provider_scope.oauth2.ids
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id
  sub_mode              = "hashed_user_id"
  pkce_enabled          = false

  allowed_redirect_uris = [
    "oc://ios.owncloud.com",
    "oc.ios://ios.owncloud.com"
  ]
}

resource "authentik_application" "ocis_ios" {
  name               = "ownCloud iOS"
  slug               = "ocis-ios"
  protocol_provider  = authentik_provider_oauth2.ocis_ios.id
  group              = authentik_group.ocis.name
  meta_icon          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/owncloud.png"
  meta_launch_url    = "https://cloud.${var.cluster_domain}/"
  policy_engine_mode = "all"
  open_in_new_tab    = true
}
