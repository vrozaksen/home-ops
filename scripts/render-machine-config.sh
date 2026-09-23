#!/usr/bin/env bash
set -Eeuo pipefail

# Description:
#   This script renders and merges Talos machine configurations using minijinja-cli, infisical and talosctl.
#   It uses templates and patches to generate a final configuration for Talos nodes.
#
# Arguments:
#   1. Path to the Talos machineconfig file.
#   2. Path to the patch file for the machineconfig.
#
# Example Usage:
#   ./render-maching-config.sh talos/machineconfig.yaml.j2 talos/nodes/k8s-0.yaml.j2
#
# Output:
#   The merged Talos configuration is printed to standard output.

readonly MACHINEBASE="${1:?}" MACHINEPATCH="${2:?}"

# Resolve talosctl through mise. A stale shell PATH can hold an older install
# that silently drops config documents it does not know -- 1.13 rendering a
# 1.14 config fails with "not registered", which is the good case; the bad one
# is a version new enough to parse but old enough to mis-handle a field.
talosctl() { mise exec -- talosctl "$@"; }

# Log messages with structured output
function log() {
    local lvl="${1:?}" msg="${2:?}"
    shift 2
    gum log --time=rfc3339 --structured --level "${lvl}" "[${FUNCNAME[1]}] ${msg}" "$@"
}

function main() {

    local base patch type result tmpdir="$(mktemp -d)"

    # Determine the machine type from the patch file
    if ! type=$(yq --exit-status 'select(documentIndex == 0) | .machine.type' "${MACHINEPATCH}") || [[ -z "${type}" ]]; then
        log fatal "Failed to determine machine type from patch file" "file" "${MACHINEPATCH}"
    fi

    # Render the base machine configurations
    if ! base=$(infisical run --env=prod --projectId=da94b011-9a7d-408b-92d9-55be47efe750 --path=/bootstrap --recursive -- minijinja-cli --define "machinetype=${type}" --env "${MACHINEBASE}") || [[ -z "${base}" ]]; then
        log fatal "Failed to render base machine configuration" "file" "${MACHINEBASE}"
    fi

    echo "${base}" >"${tmpdir}/base.yaml"

    # Render the patch machine configurations
    if ! patch=$(minijinja-cli --define "machinetype=${type}" "${MACHINEPATCH}") || [[ -z "${patch}" ]]; then
        log fatal "Failed to render patch machine configuration" "file" "${MACHINEPATCH}"
    fi

    echo "${patch}" >"${tmpdir}/patch.yaml"

    # Layer the same patches talhelper applies, in the same order: every global
    # patch, then the role patches, then this node. Keeping one set of patch
    # files is the point -- the base template used to carry hand-copied
    # duplicates of them, which is how it drifted out of sync.
    local -a patches=()
    local talosdir; talosdir="$(cd "$(dirname "${MACHINEBASE}")" && pwd)"

    local f
    local -a candidates=("${talosdir}"/patches/global/*.yaml)
    if [[ "${type}" == "controlplane" ]]; then
        candidates+=("${talosdir}"/patches/controller/*.yaml)
    else
        candidates+=("${talosdir}"/patches/worker/*.yaml)
    fi
    for f in "${candidates[@]}"; do
        [[ -e "${f}" ]] && patches+=(--patch "@${f}")
    done
    patches+=(--patch "@${tmpdir}/patch.yaml")

    # Apply the patches to the base machine configuration
    if ! result=$(talosctl machineconfig patch "${tmpdir}/base.yaml" "${patches[@]}") || [[ -z "${result}" ]]; then
        log fatal "Failed to apply patches to machine configuration" "base_file" "${tmpdir}/base.yaml" "patches" "${#patches[@]}"
    fi

    echo "${result}"
}

main "$@"
