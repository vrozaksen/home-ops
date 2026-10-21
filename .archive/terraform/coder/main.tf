terraform {
  required_version = ">= 1.0"

  required_providers {
    infisical = {
      source = "infisical/infisical"
    }

    coderd = {
      source  = "coder/coderd"
      version = "0.0.30"
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
  folder_path  = "/kubernetes/coder/coder"
  # expected key: CODER_TOFU_TOKEN (oidc user `tofu@coder.invalid`, role
  # template-admin; login-type none needs Premium service accounts)
}

# Templates go in ./templates/<name>/, each published by a coderd_template
# resource whose versions[].directory points at it.
provider "coderd" {
  url   = var.coder_url
  token = data.infisical_secrets.provider_auth.secrets["CODER_TOFU_TOKEN"].value
}
