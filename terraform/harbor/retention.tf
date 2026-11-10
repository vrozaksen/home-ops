# Untagged artifacts count too: digest pins outlive a re-pushed tag only if they are kept.
resource "harbor_retention_policy" "private" {
  for_each = harbor_project.private

  scope    = each.value.id
  schedule = "Daily"

  rule {
    most_recently_pushed = 20
    repo_matching        = "**"
    tag_matching         = "**"
    untagged_artifacts   = true
  }
}

resource "harbor_retention_policy" "proxy" {
  for_each = harbor_project.proxy

  scope    = each.value.id
  schedule = "Daily"

  rule {
    n_days_since_last_pull = 14
    repo_matching          = "**"
    tag_matching           = "**"
    untagged_artifacts     = true
  }
}

resource "harbor_garbage_collection" "main" {
  schedule        = "Weekly"
  delete_untagged = true
  workers         = 2
}
