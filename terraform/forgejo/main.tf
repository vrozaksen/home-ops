terraform {
  required_version = ">= 1.0"

  required_providers {
    infisical = {
      source = "infisical/infisical"
    }

    gitea = {
      source  = "integrations/gitea"
      version = "~> 0.6"
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

data "infisical_secrets" "forgejo" {
  env_slug     = "prod"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/kubernetes/apps/development/forgejo"
}

provider "gitea" {
  base_url = var.forgejo_url
  token    = data.infisical_secrets.forgejo.secrets["FORGEJO_TOKEN"].value
}
