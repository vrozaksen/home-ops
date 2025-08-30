#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "${0}")/lib/common.sh"

export LOG_LEVEL="debug"
export ROOT_DIR="$(git rev-parse --show-toplevel)"

# Apply the Talos configuration to all the nodes
function apply_talos_config() {
	log debug "Applying Talos configuration"

	task talos:genconfig

	cp talos/clusterconfig/talosconfig "$HOME/.talos/config"

	# Apply the Talos configuration to the nodes
	if ! nodes=$(talosctl config info --output json 2>/dev/null | jq --exit-status --raw-output '.nodes | join(" ")') || [[ -z "${nodes}" ]]; then
		log error "No Talos nodes found"
	fi

	log debug "Talos nodes discovered" "nodes=${nodes}"

	pushd "${ROOT_DIR}/talos" >/dev/null

	# Apply the Talos configuration
	for node in ${nodes}; do
		log debug "Applying Talos node configuration" "node=${node}"

		if ! output=$(talhelper gencommand apply --node "${node}" --extra-flags="--insecure" | bash 2>&1);
		then
			if [[ "${output}" == *"certificate required"* ]]; then
				log warn "Talos node is already configured, skipping apply of config" "node=${node}"
				continue
			fi
			log error "Failed to apply Talos node configuration" "node=${node}" "output=${output}"
		fi

		log info "Talos node configuration applied successfully" "node=${node}"
	done

	popd
}

# Bootstrap Talos on a controller node
function bootstrap_talos() {
	log debug "Bootstrapping Talos"

	pushd "${ROOT_DIR}/talos" >/dev/null

	if ! controller=$(talosctl config info --output json | jq --exit-status --raw-output '.endpoints[]' | shuf -n 1) || [[ -z "${controller}" ]]; then
		log error "No Talos controller found"
	fi

	log debug "Talos controller discovered" "controller=${controller}"

	until output=$(talosctl --talosconfig=./clusterconfig/talosconfig --nodes="${controller}" bootstrap 2>&1 || true) && [[ "${output}" == *"AlreadyExists"* ]]; do
		log info "Talos bootstrap in progress, waiting 10 seconds..." "controller=${controller}"
		sleep 10
	done

	popd >/dev/null
}

# Fetch the kubeconfig from a controller node
function fetch_kubeconfig() {
	log debug "Fetching kubeconfig"

	pushd "${ROOT_DIR}/talos" >/dev/null

	if ! controller=$(talosctl config info --output json | jq --exit-status --raw-output '.endpoints[]' | shuf -n 1) || [[ -z "${controller}" ]]; then
		log error "No Talos controller found"
	fi

	if ! talosctl kubeconfig --nodes "${controller}" --force --force-context-name main "$(basename "${ROOT_DIR}/kubeconfig")" &>/dev/null; then
		log error "Failed to fetch kubeconfig"
	fi

	cp "${ROOT_DIR}/kubeconfig" "$HOME/.kube/config"

	log info "Kubeconfig fetched successfully"

	popd >/dev/null
}

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

# Apply namespaces to the cluster
function apply_namespaces() {
    log info "Applying namespaces"

    local -r apps_dir="${ROOT_DIR}/kubernetes/apps"

    if [[ ! -d "${apps_dir}" ]]; then
        log error "Directory does not exist" "directory" "${apps_dir}"
    fi

    find "${apps_dir}" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | while IFS= read -r namespace; do
        if kubectl get namespace "${namespace}" &>/dev/null; then
            log info "Namespace is up-to-date" "namespace" "${namespace}"
            continue
        fi

        if ! kubectl create namespace "${namespace}" --dry-run=client --output=yaml | kubectl apply --server-side --filename - &>/dev/null; then
            log error "Failed to apply namespace" "namespace" "${namespace}"
        fi

        log info "Namespace applied successfully" "namespace" "${namespace}"
    done
}

# Apply resources before the helmfile charts are installed
function apply_resources() {
    log info "Applying resources"

    local -r resources_file="${ROOT_DIR}/bootstrap/resources.yaml.j2"

    if [[ ! -f "${resources_file}" ]]; then
        log fatal "File does not exist" "file" "${resources_file}"
    fi

    if bws run --no-inherit-env -- minijinja-cli --env "${resources_file}" | kubectl diff --filename - &>/dev/null; then
        log info "Resources are up-to-date"
        return
    fi

    if ! bws run --no-inherit-env -- minijinja-cli --env "${resources_file}" | kubectl apply --server-side --filename - &>/dev/null; then
        log fatal "Failed to apply resources"
    fi

    log info "Resources applied successfully"
}

# Apply Custom Resource Definitions (CRDs)
function apply_crds() {
    log info "Applying CRDs"

    local -r helmfile_file="${ROOT_DIR}/bootstrap/helmfile.d/00-crds.yaml"

    if [[ ! -f "${helmfile_file}" ]]; then
        log fatal "File does not exist" "file" "${helmfile_file}"
    fi

    if ! crds=$(helmfile --file "${helmfile_file}" template --include-crds --no-hooks --quiet | yq ea --exit-status 'select(.kind == "CustomResourceDefinition")' -) || [[ -z "${crds}" ]]; then
        log fatal "Failed to render CRDs from Helmfile" "file" "${helmfile_file}"
    fi

    if echo "${crds}" | kubectl diff --filename - &>/dev/null; then
        log info "CRDs are up-to-date"
        return
    fi

    if ! echo "${crds}" | kubectl apply --server-side --filename - &>/dev/null; then
        log fatal "Failed to apply crds from Helmfile" "file" "${helmfile_file}"
    fi

    log info "CRDs applied successfully"
}

# Apply applications using Helmfile
function apply_apps() {
    log info "Applying apps"

    local -r helmfile_file="${ROOT_DIR}/bootstrap/helmfile.d/01-apps.yaml"

    if [[ ! -f "${helmfile_file}" ]]; then
        log fatal "File does not exist" "file" "${helmfile_file}"
    fi

    if ! helmfile --file "${helmfile_file}" sync --hide-notes; then
        log fatal "Failed to apply apps from Helmfile" "file" "${helmfile_file}"
    fi

    log info "Apps applied successfully"
}

function main() {
	check_env KUBECONFIG
	check_cli helmfile jq kubectl kustomize minijinja-cli bws talosctl yq

	if ! bws project list &>/dev/null; then
		log error "Failed to authenticate with Bitwarden Seccret Manager CLI"
	fi

	# Bootstrap the Talos node configuration
	apply_talos_config
	bootstrap_talos
	fetch_kubeconfig

	# Apply resources and Helm releases
	wait_for_nodes
    apply_namespaces
	apply_resources
    apply_crds
	apply_apps

	log info "Congrats! The cluster is bootstrapped and Flux is syncing the Git repository"
}

main "$@"
