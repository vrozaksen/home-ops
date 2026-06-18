# Project `just` modules. Cluster lifecycle uses `task` (Taskfile.yaml); these are ad-hoc helpers.
# Usage: `just kanidm` (list), `just kanidm onboard <user> "<name>" <email> [groups...]`

mod kanidm 'kubernetes/platform/security/kanidm/justfile'
mod stunner 'kubernetes/core/network/stunner/justfile'
