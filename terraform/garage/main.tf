terraform {
  required_version = ">= 1.0"

  required_providers {
    infisical = {
      source = "infisical/infisical"
    }

    garage = {
      source  = "schwitzd/garage"
      version = "1.2.1"
    }

    # Temporary — needed for state migration (removed blocks)
    # Delete after first successful apply
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = ">= 0.11.0"
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

data "infisical_secrets" "garage" {
  env_slug     = "prod"
  workspace_id = "da94b011-9a7d-408b-92d9-55be47efe750"
  folder_path  = "/terraform/garage"
}

provider "garage" {
  host  = var.garage_url
  token = data.infisical_secrets.garage.secrets["GARAGE_ADMIN_TOKEN"].value
}
