output "projects" {
  description = "Map of project_slug -> project_id"
  value = {
    for slug, project in sentry_project.this : slug => project.internal_id
  }
}

output "team" {
  description = "Default team slug"
  value       = sentry_team.main.slug
}
