terraform {
  required_version = ">= 1.0"

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2026.2.0"
    }

    infisical = {
      source = "infisical/infisical"
    }

    random = {
      source = "hashicorp/random"
    }
  }
}

provider "infisical" {
  host = "https://eu.infisical.com"
  auth = {
    universal = {
      client_id     = var.infisical_client_id
      client_secret = var.infisical_client_secret
    }
  }
}

data "infisical_secrets" "authentik" {
  env_slug     = "prod"
  workspace_id = "da94b011-9a7d-408b-92d9-55be47efe750"
  folder_path  = "/terraform/authentik"
}

locals {
  authentik_token       = data.infisical_secrets.authentik.secrets["AUTHENTIK_TOKEN"].value
  # turnstile_site_key    = data.infisical_secrets.authentik.secrets["TURNSTILE_SITE_KEY"].value
  # turnstile_secret_key  = data.infisical_secrets.authentik.secrets["TURNSTILE_SECRET_KEY"].value
  pushover_user_key     = data.infisical_secrets.authentik.secrets["PUSHOVER_USER_KEY"].value
  pushover_api_token    = data.infisical_secrets.authentik.secrets["PUSHOVER_API_TOKEN"].value
  ldap_service_password = data.infisical_secrets.authentik.secrets["LDAP_SERVICE_PASSWORD"].value
}

provider "authentik" {
  url   = "https://sso.${var.cluster_domain}"
  token = local.authentik_token
}
