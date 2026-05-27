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

variable "sentry_url" {
  type        = string
  description = "Sentry web UI URL"
  default     = "https://sentry.vzkn.eu"
}

variable "sentry_organization" {
  type        = string
  description = "Sentry organization slug (from /organizations/<slug>/ in URL)"
  default     = "sentry"
}

variable "infisical_workspace_id" {
  type        = string
  description = "Infisical workspace ID (vzkn-eu-v2-zn)"
  default     = "da94b011-9a7d-408b-92d9-55be47efe750"
}
