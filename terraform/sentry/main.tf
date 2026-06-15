terraform {
  required_version = ">= 1.0"

  required_providers {
    infisical = {
      source = "infisical/infisical"
    }

    sentry = {
      source  = "jianyuan/sentry"
      version = "0.15.2"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
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

data "infisical_secrets" "sentry_admin" {
  env_slug     = "prod"
  workspace_id = "da94b011-9a7d-408b-92d9-55be47efe750"
  folder_path  = "/sentry/admin"
}

provider "sentry" {
  base_url = "${var.sentry_url}/api/"
  token    = data.infisical_secrets.sentry_admin.secrets["AUTH_TOKEN"].value
}

data "sentry_organization" "main" {
  slug = var.sentry_organization
}
