# Sentry Organization Auth Token — scoped for CI pipelines that need to
# create releases, upload debug-files (Rust symbols for vroxide), and update
# project state. Provider docs:
# https://registry.terraform.io/providers/jianyuan/sentry/latest/docs/resources/organization_auth_token
#
# Scopes per https://docs.sentry.io/account/auth-tokens/#scopes:
#   project:read       — list projects + DSNs
#   project:write      — update project settings
#   project:releases   — create release + upload debug-files (REQUIRED for
#                        sentry-cli debug-files upload)
#   org:read           — discover org (CLI default sanity check)
resource "sentry_organization_auth_token" "ci" {
  organization = data.sentry_organization.main.slug
  name         = "ci-pipeline"
  scopes = [
    "project:read",
    "project:write",
    "project:releases",
    "org:read",
  ]
}

# Push CI token to Infisical /sentry/ci/AUTH_TOKEN. Forgejo Actions in
# vroxide repo will pull this via dotrepos reusable workflow.
resource "infisical_secret" "ci_auth_token" {
  name         = "AUTH_TOKEN"
  value        = sentry_organization_auth_token.ci.token
  env_slug     = "prod"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/sentry/ci"
}
