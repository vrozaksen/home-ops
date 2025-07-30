terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "minio/minio.tfstate"
    region = "eu-central-1" # Region validation will be skipped

    endpoints = {
      s3 = "https://s3.vzkn.eu" # Minio endpoint
    }

    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
