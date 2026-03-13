variable "infisical_client_id" {
  type        = string
  description = "Infisical Machine Identity Client ID"
  sensitive   = true
}

variable "infisical_client_secret" {
  type        = string
  description = "Infisical Machine Identity Client Secret"
  sensitive   = true
}

variable "garage_url" {
  type        = string
  description = "Garage Admin API URL"
  default     = "admin.s3.vzkn.eu"
}
