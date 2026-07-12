terraform {
  required_version = ">= 1.0"

  required_providers {
    infisical = {
      source = "infisical/infisical"
    }

    forgejo = {
      source  = "svalabs/forgejo"
      version = "1.5.1"
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

data "infisical_secrets" "provider_auth" {
  env_slug     = "prod"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/kubernetes/development/forgejo"
  # expected key: FORGEJO_TOKEN (admin PAT with repository:write scope)
}

provider "forgejo" {
  host      = var.forgejo_url
  api_token = data.infisical_secrets.provider_auth.secrets["FORGEJO_TOKEN"].value
}
