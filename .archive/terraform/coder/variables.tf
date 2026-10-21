variable "infisical_client_id" {
  type        = string
  description = "Infisical universal-auth client id (from tofu-controller varsFrom)"
  sensitive   = true
}

variable "infisical_client_secret" {
  type        = string
  description = "Infisical universal-auth client secret (from tofu-controller varsFrom)"
  sensitive   = true
}

variable "infisical_workspace_id" {
  type        = string
  description = "Infisical workspace id (project vzkn-eu-v2-zn)"
  default     = "da94b011-9a7d-408b-92d9-55be47efe750"
}

variable "coder_url" {
  type        = string
  description = "Coder access URL"
  default     = "https://coder.vzkn.eu"
}
