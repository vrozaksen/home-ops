terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.0"
    }
  }
}

# Primary provider and application
resource "authentik_provider_proxy" "this" {
  name                  = var.name
  external_host         = "https://${var.slug}.${var.domain}"
  mode                  = "forward_single"
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

# Additional hostname providers and applications (aliases)
resource "authentik_provider_proxy" "additional" {
  for_each = toset(var.additional_hosts)

  name                  = "${var.name} (${each.value})"
  external_host         = "https://${each.value}.${var.domain}"
  mode                  = "forward_single"
  authorization_flow    = var.authorization_flow
  invalidation_flow     = var.invalidation_flow
  access_token_validity = var.access_token_validity
  skip_path_regex       = var.ignore_paths
}

resource "authentik_application" "additional" {
  for_each = toset(var.additional_hosts)

  name              = "${var.name} (${each.value})"
  slug              = each.value
  group             = var.group
  protocol_provider = authentik_provider_proxy.additional[each.value].id
  meta_description  = var.description
  meta_icon         = var.icon_url
  open_in_new_tab   = var.newtab
}

resource "authentik_policy_binding" "additional" {
  for_each = {
    for pair in flatten([
      for host in var.additional_hosts : [
        for idx, group in var.auth_groups : {
          key   = "${host}-${idx}"
          host  = host
          group = group
          order = idx
        }
      ]
    ]) : pair.key => pair
  }

  target = authentik_application.additional[each.value.host].uuid
  group  = each.value.group
  order  = each.value.order
}
