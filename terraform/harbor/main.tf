terraform {
  required_version = ">= 1.0"

  required_providers {
    infisical = {
      source = "infisical/infisical"
    }

    harbor = {
      source  = "goharbor/harbor"
      version = "~> 3.11"
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

data "infisical_secrets" "harbor_admin" {
  env_slug     = "prod"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/kubernetes/harbor/harbor"
}

data "infisical_secrets" "oidc" {
  env_slug     = "prod"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/terraform/authentik/oidc"
}

provider "harbor" {
  url      = var.harbor_url
  username = "admin"
  password = data.infisical_secrets.harbor_admin.secrets["HARBOR_ADMIN_PASSWORD"].value
}
