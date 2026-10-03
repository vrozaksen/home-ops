# Each template's source lives in ./templates/<name>; any change to that
# directory publishes a new active template version.
resource "coderd_template" "base" {
  name         = "base"
  display_name = "Base"
  description  = "Minimal Ubuntu workspace: persistent home, terminal, SSH, VS Code Desktop"
  icon         = "/icon/ubuntu.svg"

  # Idle workspaces stop after 4h; the cluster has no memory to spare.
  default_ttl_ms   = 4 * 60 * 60 * 1000
  activity_bump_ms = 60 * 60 * 1000

  versions = [{
    directory = "${path.module}/templates/base"
    active    = true
  }]
}
