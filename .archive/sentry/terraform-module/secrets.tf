resource "infisical_secret_folder" "projects_root" {
  environment_slug = "prod"
  folder_path      = "/sentry"
  name             = "projects"
  project_id       = var.infisical_workspace_id
}

resource "infisical_secret_folder" "project" {
  for_each = local.projects

  environment_slug = "prod"
  folder_path      = "/sentry/projects"
  name             = each.key
  project_id       = var.infisical_workspace_id

  depends_on = [infisical_secret_folder.projects_root]
}

# Push each project's DSN to Infisical at /sentry/projects/<slug>/DSN.
# Apps (sentry-kubernetes-agent, vroxide, gts) consume via InfisicalSecret
# pointing at /sentry/projects/<their-slug>/ path.
resource "infisical_secret" "project_dsn" {
  for_each = local.project_dsns

  name         = "DSN"
  value        = each.value
  env_slug     = "prod"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/sentry/projects/${each.key}"

  depends_on = [infisical_secret_folder.project]
}
