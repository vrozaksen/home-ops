# A key "owner/name" names a repository outside var.forgejo_owner (an
# organisation); a bare name stays under var.forgejo_owner.
data "forgejo_repository" "this" {
  for_each = local.repo_secrets

  owner = length(split("/", each.key)) == 2 ? split("/", each.key)[0] : var.forgejo_owner
  name  = element(split("/", each.key), length(split("/", each.key)) - 1)
}

resource "forgejo_repository_action_secret" "this" {
  for_each = { for s in local.flat_secrets : s.key => s }

  repository_id = data.forgejo_repository.this[each.value.repo].id
  name          = each.value.name
  data          = each.value.value
}
