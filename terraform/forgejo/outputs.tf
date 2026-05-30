output "managed_repo_secrets" {
  description = "Repo -> list of Action secret names this module manages"
  value = {
    for repo, secrets in local.repo_secrets :
    repo => keys(secrets)
  }
}
