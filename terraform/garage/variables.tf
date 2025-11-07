variable "bw_access_token" {
  type        = string
  description = "Bitwarden Secret Manager Access token"
  sensitive   = true
}

variable "garage_url" {
  type        = string
  description = "Garage Server URL"
  default     = "api.s3.vzkn.eu"
}
