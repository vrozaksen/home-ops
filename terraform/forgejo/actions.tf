resource "gitea_repository_action_secret" "this" {
  for_each = { for s in local.flat_secrets : s.key => s }

  owner       = var.forgejo_owner
  repository  = each.value.repo
  secret_name = each.value.name
  data        = each.value.value
}
