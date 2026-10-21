# ─── Multica VCS webhooks (PR state and CI status on Multica issues) ──
# Connections are made in Multica (Settings > Code, bot vzkn-agents); each
# returns a webhook secret, stored in Infisical. The URL is the in-cluster
# backend: the public multica.vzkn.eu sits behind Kanidm OIDC.
data "infisical_secrets" "multica" {
  env_slug     = "prod"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/terraform/forgejo/multica"
  # expected keys: WEBHOOK_SECRET_VZKN, WEBHOOK_SECRET_OMC
}

locals {
  multica_backend = "http://multica-backend.ai.svc.cluster.local:8080/api/webhooks/vcs"
  # Forgejo repository id -> Multica workspace connection.
  multica_connections = {
    vzkn = { id = "4bf73a66-1e4c-4102-899d-703be84c28e8", secret = "WEBHOOK_SECRET_VZKN" }
    omc  = { id = "f48437af-9fd8-466d-8043-f0b6256f8beb", secret = "WEBHOOK_SECRET_OMC" }
  }
  multica_repos = {
    "vrozaksen/agent-skills"       = { id = 250, ws = "vzkn" }
    "vrozaksen/containers"         = { id = 175, ws = "vzkn" }
    "vrozaksen/mikrotik-terraform" = { id = 174, ws = "vzkn" }
    "vrozaksen/nix-config"         = { id = 104, ws = "vzkn" }
    "Omnichassis/firmware"         = { id = 243, ws = "omc" }
    "Omnichassis/fleet"            = { id = 248, ws = "omc" }
    "Omnichassis/hardware"         = { id = 245, ws = "omc" }
    "Omnichassis/infra"            = { id = 244, ws = "omc" }
    "Omnichassis/mech"             = { id = 246, ws = "omc" }
    "Omnichassis/os"               = { id = 249, ws = "omc" }
  }
}

resource "forgejo_repository_webhook" "multica" {
  for_each      = local.multica_repos
  repository_id = each.value.id
  type          = "forgejo"
  active        = true
  # Multica also reads "status" (CI state), but svalabs/forgejo 1.7.0 rejects it.
  events = [
    "pull_request",
    "pull_request_sync",
    "pull_request_review_approved",
    "pull_request_review_rejected",
  ]
  config = {
    content_type = "json"
    url          = "${local.multica_backend}/${local.multica_connections[each.value.ws].id}"
    secret       = data.infisical_secrets.multica.secrets[local.multica_connections[each.value.ws].secret].value
  }
}
