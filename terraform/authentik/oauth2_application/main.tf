terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.0"
    }
  }
}

data "authentik_certificate_key_pair" "generated" {
  name = "authentik Self-signed Certificate"
}

data "authentik_property_mapping_provider_scope" "scopes" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-profile",
    "goauthentik.io/providers/oauth2/scope-offline_access"
  ]
}

resource "authentik_provider_oauth2" "this" {
  name                       = var.name
  client_id                  = var.client_id
  client_secret              = local.client_secret
  authorization_flow         = var.authorization_flow
  invalidation_flow          = var.invalidation_flow
  signing_key                = data.authentik_certificate_key_pair.generated.id
  client_type                = var.client_type
  include_claims_in_id_token = var.include_claims_in_id_token
  issuer_mode                = var.issuer_mode
  sub_mode                   = var.sub_mode
  access_code_validity       = var.access_code_validity
  access_token_validity      = var.access_token_validity
  property_mappings          = concat(data.authentik_property_mapping_provider_scope.scopes.ids, var.additional_property_mappings)
  allowed_redirect_uris      = local.allowed_redirect_uris
}

resource "authentik_application" "this" {
  name              = var.name
  slug              = lower(var.name)
  group             = var.group
  protocol_provider = authentik_provider_oauth2.this.id
  meta_icon         = var.icon_url
  meta_description  = var.description
  meta_launch_url   = var.launch_url
  open_in_new_tab   = var.newtab
}

resource "authentik_policy_binding" "this" {
  for_each = toset(var.auth_groups)

  target = authentik_application.this.uuid
  group  = each.value
  order  = index(var.auth_groups, each.value)
}
