resource "harbor_retention_policy" "private" {
  for_each = harbor_project.private

  scope    = each.value.id
  schedule = "Daily"

  rule {
    n_days_since_last_pull = 0
    most_recent_x_tags     = 10
    repo_matching          = "**"
    tag_matching           = "**"
    untagged_artifacts     = false
  }

  rule {
    n_days_since_last_pull = 30
    repo_matching          = "**"
    tag_matching           = "**"
    untagged_artifacts     = false
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
  schedule        = "Daily"
  delete_untagged = true
  workers         = 2
}
