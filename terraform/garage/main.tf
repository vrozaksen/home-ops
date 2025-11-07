terraform {
  required_version = ">= 1.0"

  required_providers {
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = ">= 0.11.0"
    }

    garage = {
      source  = "schwitzd/garage"
      version = "1.2.1"
    }
  }
}

provider "bitwarden" {
  access_token = var.bw_access_token
  experimental {
    embedded_client = true
  }
}

data "bitwarden_secret" "bw_proj_id" {
  key = "BW_PROJ_ID"
}

data "bitwarden_secret" "garage" {
  key = "garage"
}

locals {
  garage_admin_token = regex("GARAGE_ADMIN_TOKEN: (\\S+)", data.bitwarden_secret.garage.value)
}

provider "garage" {
  host  = var.garage_url
  token = local.garage_admin_token[0]
}
