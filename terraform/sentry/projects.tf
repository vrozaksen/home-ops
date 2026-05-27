locals {
  # Default team for new projects. Created here so terraform owns its lifecycle
  # (Sentry auto-creates "#sentry" team for first user; we want explicit one).
  team_slug = "vzkn"

  projects = {
    # ────────────────────────────────────────────────────────────────────
    # sentry-internal: Sentry self-instrumentation + sentry-kubernetes-agent
    # K8s events (OOMKilled, CrashLoop, FailedScheduling) land here.
    # Keep separate from app projects to avoid alert noise mixing.
    # ────────────────────────────────────────────────────────────────────
    "sentry-internal" = {
      name     = "Sentry Internal"
      platform = "other"
    }

    # ────────────────────────────────────────────────────────────────────
    # vroxide: Rust voice client (Slint UI, Win+Linux+macOS) — desktop
    # binary, NOT K8s service. Receives errors + profiling + breadcrumbs
    # per SENTRY.md spec (M02 milestone).
    # ────────────────────────────────────────────────────────────────────
    "vroxide" = {
      name     = "vroxide"
      platform = "rust"
    }
  }
}

resource "sentry_team" "main" {
  organization = data.sentry_organization.main.slug
  name         = "vzkn"
  slug         = local.team_slug
}

resource "sentry_project" "this" {
  for_each = local.projects

  organization = data.sentry_organization.main.slug
  teams        = [sentry_team.main.slug]
  name         = each.value.name
  slug         = each.key
  platform     = each.value.platform

  # Sentry auto-creates a default ClientKey per project. We expose its DSN
  # via sentry_all_keys data source below — pushed to Infisical for app
  # consumption.
}

# Default ClientKey (DSN) per project. Sentry creates one automatically with
# name "Default" — we read it to get the DSN string.
data "sentry_all_keys" "this" {
  for_each = sentry_project.this

  organization = data.sentry_organization.main.slug
  project      = each.value.slug
}

locals {
  # Map of project_slug -> DSN. Filter to "Default" key (auto-created).
  # Use `dsn["public"]` (map access) — `dsn_public` field is deprecated
  # in jianyuan/sentry 0.14+ in favor of the dsn map.
  project_dsns = {
    for slug, keys in data.sentry_all_keys.this :
    slug => [for k in keys.keys : k.dsn["public"] if k.name == "Default"][0]
  }
}
