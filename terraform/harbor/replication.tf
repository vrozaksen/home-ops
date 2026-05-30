resource "harbor_registry" "ghcr_outbound" {
  name          = "ghcr-vrozaksen-out"
  endpoint_url  = "https://ghcr.io"
  provider_name = "github"
  description   = "ghcr.io/vrozaksen mirror target"

  access_id     = "vrozaksen"
  access_secret = data.infisical_secrets.harbor_admin.secrets["GHCR_PUSH_TOKEN"].value
}

resource "harbor_replication" "containers_to_ghcr" {
  name        = "containers-mirror-to-ghcr"
  description = "Mirror containers/* to ghcr.io/vrozaksen/* on every push"
  action      = "push"
  registry_id = harbor_registry.ghcr_outbound.registry_id

  filters {
    name = "containers/**"
  }
  filters {
    resource = "image"
  }

  trigger {
    type = "event_based"
    trigger_settings {
      empty_jobs = false
    }
  }

  override               = true
  enabled                = true
  deletion               = false
  speed                  = -1
  dest_namespace_replace = 1
  dest_namespace         = "vrozaksen"
}
