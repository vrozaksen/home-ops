terraform {
  required_version = ">= 1.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.12.0"
    }

    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = ">= 0.11.0"
    }
  }
}

provider "bitwarden" {
  access_token = var.bw_access_token
  experimental {
    embedded_client = true
  }
}

data "bitwarden_secret" "authentik" {
  key = "authentik"
}

locals {
  authentik_token       = regex("AUTHENTIK_TOKEN: (\\S+)", data.bitwarden_secret.authentik.value)[0]
  turnstile_site_key    = regex("TURNSTILE_SITE_KEY: (\\S+)", data.bitwarden_secret.authentik.value)[0]
  turnstile_secret_key  = regex("TURNSTILE_SECRET_KEY: (\\S+)", data.bitwarden_secret.authentik.value)[0]
  pushover_user_key     = regex("PUSHOVER_USER_KEY: (\\S+)", data.bitwarden_secret.authentik.value)[0]
  pushover_api_token    = regex("PUSHOVER_API_TOKEN: (\\S+)", data.bitwarden_secret.authentik.value)[0]
}

provider "authentik" {
  url   = "https://sso.${var.cluster_domain}"
  token = local.authentik_token
}
