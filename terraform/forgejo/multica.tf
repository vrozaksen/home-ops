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
  # agents: collaborator permission of the bot; repos without it keep agents read-only.
  multica_repos = {
    "vrozaksen/agent-skills"       = { id = 250, ws = "vzkn" }
    "vrozaksen/containers"         = { id = 175, ws = "vzkn", agents = "write" }
    "vrozaksen/mikrotik-terraform" = { id = 174, ws = "vzkn" }
    "vrozaksen/nix-config"         = { id = 104, ws = "vzkn" }
    "Omnichassis/engineering"      = { id = 283, ws = "omc", agents = "write" }
    "Omnichassis/firmware"         = { id = 243, ws = "omc", agents = "write" }
    "Omnichassis/fleet"            = { id = 248, ws = "omc", agents = "write" }
    "Omnichassis/hardware"         = { id = 245, ws = "omc", agents = "write" }
    "Omnichassis/infra"            = { id = 244, ws = "omc", agents = "write" }
    "Omnichassis/mech"             = { id = 246, ws = "omc", agents = "write" }
    "Omnichassis/os"               = { id = 249, ws = "omc", agents = "write" }
  }
}

# Agent bot access per repo, so a new repo in the map gets push and the webhook together.
resource "forgejo_collaborator" "agents" {
  for_each      = { for k, v in local.multica_repos : k => v if try(v.agents, null) != null }
  repository_id = each.value.id
  user          = "vzkn-agents"
  permission    = each.value.agents
}

resource "forgejo_repository_webhook" "multica" {
  for_each      = local.multica_repos
  repository_id = each.value.id
  type          = "forgejo"
  active        = true
  # The whole pull_request family: Forgejo expands "pull_request" into it, and a
  # partial list makes the provider fail with an inconsistent result. Multica also
  # reads "status" (CI state), but svalabs/forgejo 1.7.0 rejects that event.
  events = [
    "pull_request",
    "pull_request_assign",
    "pull_request_comment",
    "pull_request_label",
    "pull_request_milestone",
    "pull_request_review_approved",
    "pull_request_review_comment",
    "pull_request_review_rejected",
    "pull_request_review_request",
    "pull_request_sync",
  ]
  config = {
    content_type = "json"
    url          = "${local.multica_backend}/${local.multica_connections[each.value.ws].id}"
    secret       = data.infisical_secrets.multica.secrets[local.multica_connections[each.value.ws].secret].value
  }
}
