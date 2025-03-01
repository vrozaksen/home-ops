#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "${0}")/lib/common.sh"

export LOG_LEVEL="debug"
export ROOT_DIR="$(git rev-parse --show-toplevel)"

# Talos requires the nodes to be 'Ready=False' before applying resources
function wait_for_nodes() {
    log debug "Waiting for nodes to be available"

    # Skip waiting if all nodes are 'Ready=True'
    if kubectl wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then
        log info "Nodes are available and ready, skipping wait for nodes"
        return
    fi

    # Wait for all nodes to be 'Ready=False'
    until kubectl wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do
        log info "Nodes are not available, waiting for nodes to be available. Retrying in 10 seconds..."
        sleep 10
    done
}

# Disks in use by rook-ceph must be wiped before Rook is installed
function wipe_rook_disks() {
    log debug "Wiping Rook disks"

    # Skip disk wipe if Rook is detected running in the cluster
    # TODO: Is there a better way to detect Rook / OSDs?
    if kubectl --namespace rook-ceph get kustomization rook-ceph &>/dev/null; then
        log warn "Rook is detected running in the cluster, skipping disk wipe"
        return
    fi

    if ! nodes=$(talosctl config info --output json 2>/dev/null | jq --exit-status --raw-output '.nodes | join(" ")') || [[ -z "${nodes}" ]]; then
        log error "No Talos nodes found"
    fi

    log debug "Talos nodes discovered" "nodes=${nodes}"

    # Wipe disks on each node that match the CSI_DISK environment variable
    for node in ${nodes}; do
        if ! disks=$(talosctl --nodes "${node}" get disk --output json 2>/dev/null \
            | jq --exit-status --raw-output --slurp '. | map(select(.spec.model == env.CSI_DISK) | .metadata.id) | join(" ")') || [[ -z "${nodes}" ]];
        then
            log error "No disks found" "node=${node}" "model=${CSI_DISK}"
        fi

        log debug "Talos node and disk discovered" "node=${node}" "disks=${disks}"

        # Wipe each disk on the node
        for disk in ${disks}; do
            if talosctl --nodes "${node}" wipe disk "${disk}" &>/dev/null; then
                log info "Disk wiped" "node=${node}" "disk=${disk}"
            else
                log error "Failed to wipe disk" "node=${node}" "disk=${disk}"
            fi
        done
    done
}

# The application namespaces are created before applying the resources
function apply_namespaces() {
    log debug "Applying namespaces"

    local -r apps_dir="${KUBERNETES_DIR}/apps"

    if [[ ! -d "${apps_dir}" ]]; then
        log fatal "Directory does not exist" directory "${apps_dir}"
    fi

    for app in "${apps_dir}"/*/; do
        namespace=$(basename "${app}")

        # Check if the namespace resources are up-to-date
        if kubectl get namespace "${namespace}" &>/dev/null; then
            log info "Namespace resource is up-to-date" resource "${namespace}"
            continue
        fi

        # Apply the namespace resources
        if kubectl create namespace "${namespace}" --dry-run=client --output=yaml \
            | kubectl apply --server-side --filename - &>/dev/null;
        then
            log info "Namespace resource applied" resource "${namespace}"
        else
            log fatal "Failed to apply namespace resource" resource "${namespace}"
        fi
    done
}

# Secrets to be applied before the helmfile charts are installed
function apply_secrets() {
    log debug "Applying secrets"

    local -r secrets_file="${ROOT_DIR}/bootstrap/secrets.yaml.tpl"
    local resources

    if [[ ! -f "${secrets_file}" ]]; then
        log fatal "File does not exist" file "${secrets_file}"
    fi

    log debug "Exporting secrets from Bitwarden"
    secrets=$(bws secret list --output env d78877ca-d005-4973-b288-b24e00bdef1d | grep -Ff ${ROOT_DIR}/bootstrap/.secrets.env)

    if [[ -z "${secrets}" ]]; then
        log fatal "No secrets found or secrets are empty"
        exit 1
    fi

    export ${secrets}

    log debug "Rendering template"
    if ! resources=$(envsubst < "${secrets_file}"); then
        log fatal "Failed to render template" file "${secrets_file}"
        exit 1
    fi

    # Check if the secret resources are up-to-date
    if echo "${resources}" | kubectl diff --filename - &>/dev/null; then
        log info "Secret resources are up-to-date"
        return
    fi

    # Apply secret resources
    if echo "${resources}" | kubectl apply --server-side --filename - &>/dev/null; then
        log info "Secret resources applied"
    else
        log fatal "Failed to apply secret resources"
    fi

    # Cleanup envs
    log debug "Clearing environment variables"
    for var in $(bws secret list --output env d78877ca-d005-4973-b288-b24e00bdef1d | cut -d= -f1); do
        unset "$var"
    done
}

# Apply Helm releases using helmfile
function apply_helm_releases() {
    log debug "Applying Helm releases with helmfile"

    local -r helmfile_file="${ROOT_DIR}/bootstrap/helmfile.yaml"

    if [[ ! -f "${helmfile_file}" ]]; then
        log error "File does not exist" "file=${helmfile_file}"
    fi

    if ! helmfile --file "${helmfile_file}" apply --hide-notes --skip-diff-on-install --suppress-diff --suppress-secrets; then
        log error "Failed to apply Helm releases"
    fi

    log info "Helm releases applied successfully"
}

function main() {
    check_env KUBECONFIG KUBERNETES_VERSION CSI_DISK TALOS_VERSION
    check_cli helmfile jq kubectl kustomize minijinja-cli bws talosctl yq

    # TODO
    # Bootstrap the Talos node configuration
    # apply_talos_config
    # bootstrap_talos
    # fetch_kubeconfig

    # Apply resources and Helm releases
    wait_for_nodes
    wipe_rook_disks
    #apply_resources # TODO Maybe I can use that someday when bws-cli will be released
    apply_namespaces
    apply_secrets
    apply_helm_releases

    log info "Congrats! The cluster is bootstrapped and Flux is syncing the Git repository"
}

main "$@"
