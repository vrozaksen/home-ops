# ─── Harbor robot creds (terraform-managed by terraform/harbor) ────────
data "infisical_secrets" "harbor_robot_containers" {
  env_slug     = "prod"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/kubernetes/harbor/robots/containers"
}

data "infisical_secrets" "harbor_robot_vroxide" {
  env_slug     = "prod"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/kubernetes/harbor/robots/vroxide"
}

# ─── CI-side secrets (BOT_TOKEN + COSIGN_* + PUSHOVER_*) ──────────────
data "infisical_secrets" "forgejo_actions" {
  env_slug     = "prod"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/forgejo-actions"
  # expected keys:
  #   BOT_TOKEN, COSIGN_KEY, COSIGN_PASSWORD,
  #   PUSHOVER_APP_TOKEN, PUSHOVER_USER_KEY
}

# ─── Attic CI token (used by nix-config + vroxide for `attic push`) ───
data "infisical_secrets" "attic" {
  env_slug     = "prod"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/kubernetes/development/attic"
  # expected keys: PULL_TOKEN  (push+pull combined)
}
