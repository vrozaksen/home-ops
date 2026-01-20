terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.0"
    }
  }
}

resource "authentik_provider_proxy" "this" {
  name                  = var.name
  external_host         = "https://${var.slug}.${var.domain}"
  mode                  = length(var.additional_hosts) > 0 ? "forward_domain" : "forward_single"
  cookie_domain         = length(var.additional_hosts) > 0 ? var.domain : null
  authorization_flow    = var.authorization_flow
  invalidation_flow     = var.invalidation_flow
  access_token_validity = var.access_token_validity
  skip_path_regex       = var.ignore_paths
}

resource "authentik_application" "this" {
  name              = var.name
  slug              = var.slug
  group             = var.group
  protocol_provider = authentik_provider_proxy.this.id
  meta_description  = var.description
  meta_icon         = var.icon_url
  open_in_new_tab   = var.newtab
}

resource "authentik_policy_binding" "this" {
  for_each = { for idx, group in var.auth_groups : idx => group }

  target = authentik_application.this.uuid
  group  = each.value
  order  = each.key
}
