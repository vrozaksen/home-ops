terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "forgejo/forgejo.tfstate"
    region = "eu-central-1"

    endpoints = {
      s3 = "https://api.s3.vzkn.eu"
    }

    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
    use_lockfile                = true
  }
}
