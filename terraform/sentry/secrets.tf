resource "infisical_secret" "project_dsn" {
  for_each = local.project_dsns

  name         = "DSN"
  value        = each.value
  env_slug     = "prod"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/sentry/projects/${each.key}"
}
