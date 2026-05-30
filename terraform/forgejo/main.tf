terraform {
  required_version = ">= 1.0"

  required_providers {
    infisical = {
      source = "infisical/infisical"
    }

    gitea = {
      source  = "lerentis/gitea"
      version = "~> 0.13"
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
  folder_path  = "/kubernetes/apps/development/forgejo"
  # expected key: FORGEJO_TOKEN (admin PAT with repository:write scope)
}

provider "gitea" {
  base_url = var.forgejo_url
  token    = data.infisical_secrets.provider_auth.secrets["FORGEJO_TOKEN"].value
}
