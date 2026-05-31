# Map: repository -> { secret name -> Infisical value }.
#
# Add a new repo by inserting another key; add a new secret to an existing
# repo by extending its inner map. `gitea_repository_action_secret` is
# created per (repo, name) pair via the flatten loop in `actions.tf`.
locals {
  repo_secrets = {
    "containers" = {
      # Harbor robot account — push/pull to project `containers`.
      REGISTRY_USERNAME = data.infisical_secrets.harbor_robot_containers.secrets["HARBOR_ROBOT_NAME"].value
      REGISTRY_PASSWORD = data.infisical_secrets.harbor_robot_containers.secrets["HARBOR_ROBOT_TOKEN"].value

      # Notification on release-build failure (CI-scoped Pushover app —
      # separate from the cluster-side alertmanager Pushover credentials).
      PUSHOVER_USER_KEY  = data.infisical_secrets.forgejo_actions.secrets["PUSHOVER_USER_KEY"].value
      PUSHOVER_APP_TOKEN = data.infisical_secrets.forgejo_actions.secrets["PUSHOVER_APP_TOKEN"].value

      # Forgejo PAT for retry-release dispatch, sticky PR comments,
      # release creation. Scopes needed: write:issue, write:repository.
      BOT_TOKEN = data.infisical_secrets.forgejo_actions.secrets["BOT_TOKEN"].value

      # Cosign key pair for manifest signing + SLSA attest.
      COSIGN_KEY      = data.infisical_secrets.forgejo_actions.secrets["COSIGN_KEY"].value
      COSIGN_PASSWORD = data.infisical_secrets.forgejo_actions.secrets["COSIGN_PASSWORD"].value
    }

    # nix-config calls dotrepos `nix.yml` × 3 (ragnarok / mimir / installer)
    # which `attic push` the closure to cache.vzkn.eu/main.
    "nix-config" = {
      ATTIC_TOKEN = data.infisical_secrets.attic.secrets["PULL_TOKEN"].value
    }

    # vroxide standalone ci.yml: pushes to Attic for nix cache + Harbor for
    # signed OCI release artifacts (binaries + SBOM). Cosign key shared with
    # containers — single signing identity across vzkn-eu org.
    "vroxide" = {
      ATTIC_TOKEN = data.infisical_secrets.attic.secrets["PULL_TOKEN"].value

      REGISTRY_USERNAME = data.infisical_secrets.harbor_robot_vroxide.secrets["HARBOR_ROBOT_NAME"].value
      REGISTRY_PASSWORD = data.infisical_secrets.harbor_robot_vroxide.secrets["HARBOR_ROBOT_TOKEN"].value

      COSIGN_KEY      = data.infisical_secrets.forgejo_actions.secrets["COSIGN_KEY"].value
      COSIGN_PASSWORD = data.infisical_secrets.forgejo_actions.secrets["COSIGN_PASSWORD"].value

      BOT_TOKEN = data.infisical_secrets.forgejo_actions.secrets["BOT_TOKEN"].value

      PUSHOVER_USER_KEY  = data.infisical_secrets.forgejo_actions.secrets["PUSHOVER_USER_KEY"].value
      PUSHOVER_APP_TOKEN = data.infisical_secrets.forgejo_actions.secrets["PUSHOVER_APP_TOKEN"].value
    }
  }

  # Flatten {repo: {name: value}} -> [{repo, name, value, key}] for for_each.
  flat_secrets = flatten([
    for repo, secrets in local.repo_secrets : [
      for name, value in secrets : {
        key   = "${repo}/${name}"
        repo  = repo
        name  = name
        value = value
      }
    ]
  ])
}
