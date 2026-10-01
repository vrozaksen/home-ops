# Each template's source lives in ./templates/<name>; any change to that
# directory publishes a new active template version.
resource "coderd_template" "rebound" {
  name         = "rebound"
  display_name = "REBOUND"
  description  = "N-body simulations: REBOUND + REBOUNDx in JupyterLab"
  icon         = "/emojis/1fa90.png"

  # Idle workspaces stop after 4h; the cluster has no memory to spare.
  default_ttl_ms   = 4 * 60 * 60 * 1000
  activity_bump_ms = 60 * 60 * 1000

  versions = [{
    directory = "${path.module}/templates/rebound"
    active    = true
  }]
}
