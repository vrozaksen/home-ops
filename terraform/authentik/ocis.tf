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

data "authentik_property_mapping_provider_scope" "offline_access" {
  managed = "goauthentik.io/providers/oauth2/scope-offline_access"
}

# Web Client (Public)
resource "authentik_provider_oauth2" "ocis_web" {
  name                  = "ocis-web-provider"
  client_id             = local.ocis_secrets["OCIS_WEB_CLIENT_ID"]
  client_secret         = null
  client_type           = "public"
  authorization_flow    = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow   = authentik_flow.authentication.uuid
  invalidation_flow     = data.authentik_flow.default-provider-invalidation-flow.id
  property_mappings     = data.authentik_property_mapping_provider_scope.oauth2.ids
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://cloud.${var.cluster_domain}/"
    },
    {
      matching_mode = "strict"
      url           = "https://cloud.${var.cluster_domain}/oidc-callback.html"
    },
    {
      matching_mode = "strict"
      url           = "https://cloud.${var.cluster_domain}/oidc-silent-redirect.html"
    }
  ]
}

resource "authentik_application" "ocis_web" {
  name               = "ownCloud Web"
  slug               = "ocis-web"
  protocol_provider  = authentik_provider_oauth2.ocis_web.id
  group              = "Ocis"
  meta_icon          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/owncloud.png"
  meta_launch_url    = "https://cloud.${var.cluster_domain}/"
  policy_engine_mode = "all"
  open_in_new_tab    = true
}

# Desktop Client (Confidential)
resource "authentik_provider_oauth2" "ocis_desktop" {
  name                  = "ocis-desktop-provider"
  client_id             = local.ocis_secrets["OCIS_DESKTOP_CLIENT_ID"]
  client_secret         = local.ocis_secrets["OCIS_DESKTOP_CLIENT_SECRET"]
  client_type           = "confidential"
  authorization_flow    = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow   = authentik_flow.authentication.uuid
  invalidation_flow     = data.authentik_flow.default-provider-invalidation-flow.id
  property_mappings = concat(
  data.authentik_property_mapping_provider_scope.oauth2.ids,
  [data.authentik_property_mapping_provider_scope.offline_access.id]
  )
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id

  allowed_redirect_uris = [
    {
      matching_mode = "regex"
      url           = "http://127.0.0.1(:.*)?"
    },
    {
      matching_mode = "regex"
      url           = "http://localhost(:.*)?"
    }
  ]
}

resource "authentik_application" "ocis_desktop" {
  name               = "ownCloud Desktop"
  slug               = "ocis-desktop"
  protocol_provider  = authentik_provider_oauth2.ocis_desktop.id
  group              = "Ocis"
  meta_icon          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/owncloud.png"
  meta_launch_url    = "blank://blank"
  policy_engine_mode = "all"
  open_in_new_tab    = true
}

# Android Client (Confidential)
resource "authentik_provider_oauth2" "ocis_android" {
  name                  = "ocis-android-provider"
  client_id             = local.ocis_secrets["OCIS_ANDROID_CLIENT_ID"]
  client_secret         = local.ocis_secrets["OCIS_ANDROID_CLIENT_SECRET"]
  client_type           = "confidential"
  authorization_flow    = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow   = authentik_flow.authentication.uuid
  invalidation_flow     = data.authentik_flow.default-provider-invalidation-flow.id
  property_mappings = concat(
  data.authentik_property_mapping_provider_scope.oauth2.ids,
  [data.authentik_property_mapping_provider_scope.offline_access.id]
  )
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "oc://android.owncloud.com"
    }
  ]
}

resource "authentik_application" "ocis_android" {
  name               = "ownCloud Android"
  slug               = "ocis-android"
  protocol_provider  = authentik_provider_oauth2.ocis_android.id
  group              = "Ocis"
  meta_icon          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/owncloud.png"
  meta_launch_url    = "blank://blank"
  policy_engine_mode = "all"
  open_in_new_tab    = true
}

# iOS Client (Confidential)
resource "authentik_provider_oauth2" "ocis_ios" {
  name                  = "ocis-ios-provider"
  client_id             = local.ocis_secrets["OCIS_IOS_CLIENT_ID"]
  client_secret         = local.ocis_secrets["OCIS_IOS_CLIENT_SECRET"]
  client_type           = "confidential"
  authorization_flow    = authentik_flow.provider-authorization-implicit-consent.uuid
  authentication_flow   = authentik_flow.authentication.uuid
  invalidation_flow     = data.authentik_flow.default-provider-invalidation-flow.id
  property_mappings = concat(
  data.authentik_property_mapping_provider_scope.oauth2.ids,
  [data.authentik_property_mapping_provider_scope.offline_access.id]
  )
  access_token_validity = "hours=4"
  signing_key           = data.authentik_certificate_key_pair.generated.id

  allowed_redirect_uris = [
    {
      matching_mode = "strict"
      url           = "oc://ios.owncloud.com"
    },
    {
      matching_mode = "strict"
      url           = "oc.ios://ios.owncloud.com"
    }
  ]
}

resource "authentik_application" "ocis_ios" {
  name               = "ownCloud iOS"
  slug               = "ocis-ios"
  protocol_provider  = authentik_provider_oauth2.ocis_ios.id
  group              = "Ocis"
  meta_icon          = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/png/owncloud.png"
  meta_launch_url    = "blank://blank"
  policy_engine_mode = "all"
  open_in_new_tab    = true
}
