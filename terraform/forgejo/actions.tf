data "forgejo_repository" "this" {
  for_each = local.repo_secrets

  owner = var.forgejo_owner
  name  = each.key
}

resource "forgejo_repository_action_secret" "this" {
  for_each = { for s in local.flat_secrets : s.key => s }

  repository_id = data.forgejo_repository.this[each.value.repo].id
  name          = each.value.name
  data          = each.value.value
}
