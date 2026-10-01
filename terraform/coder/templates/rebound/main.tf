terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "2.19.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.3.0"
    }
  }
}

# The provisioner runs inside the coder pod; its SA can manage pods, PVCs and
# deployments in this namespace only (chart serviceAccount.workspacePerms).
provider "kubernetes" {}

variable "namespace" {
  type        = string
  description = "Namespace for workspace resources"
  default     = "coder"
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU limit"
  description  = "Cores a simulation may burst to. The request stays small."
  type         = "number"
  default      = "4"
  mutable      = true
  order        = 1
  option {
    name  = "2 cores"
    value = "2"
  }
  option {
    name  = "4 cores"
    value = "4"
  }
  option {
    name  = "5 cores"
    value = "5"
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory limit"
  description  = "GiB. Workers are near their memory reservations, so start small."
  type         = "number"
  default      = "2"
  mutable      = true
  order        = 2
  option {
    name  = "2 GiB"
    value = "2"
  }
  option {
    name  = "4 GiB"
    value = "4"
  }
  option {
    name  = "8 GiB"
    value = "8"
  }
}

data "coder_parameter" "home_disk_size" {
  name         = "home_disk_size"
  display_name = "Home disk size"
  description  = "GiB, ceph-block. Fixed at creation."
  type         = "number"
  default      = "5"
  mutable      = false
  order        = 3
  validation {
    min = 1
    max = 50
  }
}

locals {
  name = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
  labels = {
    "app.kubernetes.io/name"     = "coder-workspace"
    "app.kubernetes.io/instance" = local.name
    "app.kubernetes.io/part-of"  = "coder"
    "com.coder.resource"         = "true"
    "com.coder.workspace.id"     = data.coder_workspace.me.id
    "com.coder.user.id"          = data.coder_workspace_owner.me.id
  }
}

resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"

  # Examples are seeded once and never overwritten, so edits survive restarts.
  # Jupyter binds to loopback only: the agent tunnel is its sole way in.
  startup_script = <<-EOT
    set -e
    cp -r --update=none /etc/skel/. ~/
    mkdir -p ~/examples
    cp -r --update=none /opt/rebound/examples/. ~/examples/
    nohup jupyter lab --no-browser \
      --ServerApp.ip=127.0.0.1 --ServerApp.port=8888 \
      --ServerApp.allow_remote_access=True \
      --IdentityProvider.token= --ServerApp.password= \
      --ServerApp.root_dir="$HOME" \
      > /tmp/jupyter.log 2>&1 &
  EOT

  display_apps {
    vscode          = false
    vscode_insiders = false
    web_terminal    = true
    ssh_helper      = true
  }

  metadata {
    display_name = "CPU"
    key          = "cpu"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "Memory"
    key          = "mem"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
  metadata {
    display_name = "Home disk"
    key          = "home"
    script       = "coder stat disk --path $HOME"
    interval     = 60
    timeout      = 1
  }
}

resource "coder_app" "jupyter" {
  agent_id     = coder_agent.main.id
  slug         = "jupyter"
  display_name = "JupyterLab"
  icon         = "/icon/jupyter.svg"
  url          = "http://localhost:8888"
  # Path-based apps are disabled server-side (CODER_DISABLE_PATH_APPS).
  subdomain = true
  share     = "owner"

  healthcheck {
    url       = "http://localhost:8888/api"
    interval  = 5
    threshold = 20
  }
}

resource "kubernetes_persistent_volume_claim_v1" "home" {
  metadata {
    name      = "${local.name}-home"
    namespace = var.namespace
    labels    = local.labels
  }
  wait_until_bound = false
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "ceph-block"
    resources {
      requests = {
        storage = "${data.coder_parameter.home_disk_size.value}Gi"
      }
    }
  }
  # Survives stop/start; only workspace deletion removes it. Ignoring changes
  # keeps an edit here from ever replacing (and wiping) an existing home.
  lifecycle {
    ignore_changes = all
  }
}

resource "kubernetes_deployment_v1" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim_v1.home
  ]
  wait_for_rollout = false

  metadata {
    name      = local.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = 1
    selector {
      match_labels = local.labels
    }
    # RWO home volume: never run two pods against it.
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = local.labels
      }
      spec {
        security_context {
          run_as_user     = 1000
          run_as_group    = 1000
          run_as_non_root = true
          fs_group        = 1000
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = "dev"
          image             = "registry.vzkn.eu/containers/rebound:5.2.1"
          image_pull_policy = "IfNotPresent"
          command           = ["sh", "-c", coder_agent.main.init_script]

          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }

          # Idle Jupyter + kernel sits around 300Mi; simulations burst into the limit.
          resources {
            requests = {
              cpu    = "50m"
              memory = "384Mi"
            }
            limits = {
              cpu    = data.coder_parameter.cpu.value
              memory = "${data.coder_parameter.memory.value}Gi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.home.metadata[0].name
          }
        }

        # Control planes have 12Gi soldered and no headroom.
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "node-role.kubernetes.io/control-plane"
                  operator = "DoesNotExist"
                }
              }
            }
          }
        }
      }
    }
  }
}
