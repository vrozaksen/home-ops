resource "harbor_immutable_tag_rule" "containers" {
  project_id    = harbor_project.private["containers"].id
  repo_matching = "**"
  tag_matching  = "**"
  tag_excluding = "rolling,sandbox,latest,main"
}

resource "harbor_immutable_tag_rule" "home_ops" {
  project_id    = harbor_project.private["home-ops"].id
  repo_matching = "**"
  tag_matching  = "**"
  tag_excluding = "main,latest"
}
