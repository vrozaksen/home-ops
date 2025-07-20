output "id" {
  description = "The ID of the OAuth2 provider"
  value       = authentik_provider_oauth2.this.id
}

output "uuid" {
  description = "The UUID of the OAuth2 application"
  value       = authentik_application.this.uuid
}

output "client_id" {
  description = "The client ID of the OAuth2 application"
  value       = authentik_provider_oauth2.this.client_id
  sensitive   = true
}

output "client_secret" {
  description = "The client secret of the OAuth2 application"
  value       = authentik_provider_oauth2.this.client_secret
  sensitive   = true
}
