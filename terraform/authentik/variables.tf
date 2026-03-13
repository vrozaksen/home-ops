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

variable "cluster_domain" {
  type        = string
  description = "Domain for Authentik"
  default     = "vzkn.eu"
}
