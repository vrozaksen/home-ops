# ─────────────────────────────────────────────────────────────────────────────
# Cluster lifecycle and ad-hoc helpers.
#
#     just                        # list every recipe
#     just talos apply-node eir
#     just kube apply-ks database pgadmin
#     just kanidm onboard ania "Ania K" ania@vzkn.eu users
# ─────────────────────────────────────────────────────────────────────────────

set unstable
set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

# mise exports these too; repeated so the recipes also work for someone who
# only has just and a kubeconfig.
export KUBECONFIG := justfile_directory() / "kubeconfig"
export TALOSCONFIG := justfile_directory() / "talosconfig"
export MINIJINJA_CONFIG_FILE := justfile_directory() / ".minijinja.toml"

INFISICAL_PROJECT := "da94b011-9a7d-408b-92d9-55be47efe750"
INFISICAL_ENV := "prod"

mod bootstrap 'bootstrap/justfile'
mod kube 'kubernetes/justfile'
mod talos 'talos/justfile'
mod kanidm 'kubernetes/platform/security/kanidm/justfile'
mod stunner 'kubernetes/core/network/stunner/justfile'

[private]
default:
    just --list

[doc('Push kubeconfig and talosconfig to Infisical')]
[group('Infisical')]
push-config:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v infisical >/dev/null
    args=(--env={{ INFISICAL_ENV }} --projectId={{ INFISICAL_PROJECT }} --path=/bootstrap/kubeconfig)
    infisical secrets set KUBECONFIG_FLAT="$(kubectl config view --flatten)" "${args[@]}"
    infisical secrets set KUBECONFIG_BASE64="$(kubectl config view --flatten | base64 -w 0)" "${args[@]}"
    infisical secrets set KUBECONFIG_MAIN_BASE64="$(cat "$KUBECONFIG")" "${args[@]}"
    infisical secrets set TALOSCONFIG_MAIN="$(cat "$TALOSCONFIG")" "${args[@]}"
    infisical secrets set TALOSCONFIG_MAIN_BASE64="$(base64 -w 0 < "$TALOSCONFIG")" "${args[@]}"

[confirm('Overwrite the local kubeconfig and talosconfig from Infisical [y|N] ?')]
[doc('Pull kubeconfig and talosconfig from Infisical')]
[group('Infisical')]
pull-config:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v infisical >/dev/null
    mkdir -p ~/.kube ~/.talos
    args=(--env={{ INFISICAL_ENV }} --projectId={{ INFISICAL_PROJECT }} --path=/bootstrap/kubeconfig)
    infisical run "${args[@]}" -- bash -c 'echo "$KUBECONFIG_MAIN_BASE64"' > "$KUBECONFIG"
    infisical run "${args[@]}" -- bash -c 'echo "$TALOSCONFIG_MAIN"' > "$TALOSCONFIG"
    infisical run "${args[@]}" -- bash -c 'echo "$KUBECONFIG_FLAT"' > ~/.kube/config
    infisical run "${args[@]}" -- bash -c 'echo "$TALOSCONFIG_MAIN"' > ~/.talos/config
