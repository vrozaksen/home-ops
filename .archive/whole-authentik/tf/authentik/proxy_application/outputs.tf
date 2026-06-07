output "id" {
  description = "The ID of the proxy provider"
  value       = authentik_provider_proxy.this.id
}

output "uuid" {
  description = "The UUID of the proxy application"
  value       = authentik_application.this.uuid
}
