# forge

Persistent SSH-only dev workstation pod. Single source of truth for code,
shell history, AI agent state — accessible from any device with SSH.

## What it gives you

- **Persistent shell sessions** (zellij) — detach from PC, attach from laptop or
  phone, same state.
- **Remote dev** — Zed (`zed ssh://forge.vzkn.eu:2222/path`), VSCode Remote-SSH,
  Neovim, Helix. LSP, builds and runtime stay on the pod.
- **AI agents** (Claude Code, Gemini CLI) keep their memories on the PVC and
  integrate with the cluster `agentmemory` service.
- **In-cluster ops** — kubectl / talosctl / flux without leaving the editor.

## Architecture

| Component | Role |
| --- | --- |
| `Deployment` (single replica, `Recreate`) | Plain sshd pod, no sidecars. |
| PVC `forge` (50Gi ceph-block, via volsync) | `subPath: home` → `/home/vrozaksen`, `subPath: keys` → `/etc/ssh/keys`. |
| Service `forge-ssh:22` (ClusterIP) | Targeted by towonel-agent passthrough. |
| Towonel agent | TCP forward `forge-ssh.development:22` → bifrost VPS `:2222`. |
| DNSEndpoint | `forge.vzkn.eu` → VPS IP via external-dns. |
| Volsync (Kopia) | Hourly snapshots → S3 (24h/10d/5w/3m retention). |

## SSH security

- OpenSSH 9.9+ with post-quantum hybrid KEX (`mlkem768x25519-sha256`).
- Pubkey auth only — no password, no PAM, no challenge-response.
- `AllowUsers vrozaksen`, `MaxAuthTries 3`, `ClientAliveInterval 60`.
- Authorized keys mounted from Infisical (`/kubernetes/development/forge/AUTHORIZED_KEYS`,
  multi-line value, one pubkey per line).
- Host keys persisted on PVC — clients never see "host key changed" after restart.
- Pod runs with minimal sshd capability set, seccomp RuntimeDefault, no SA token mounted.

## Bring-up

1. Add `AUTHORIZED_KEYS` (multi-line ssh pubkeys) to Infisical
   `/kubernetes/development/forge/`.
2. Flux reconciles; wait for `forge` Deployment ready.
3. From any client:
   ```sh
   ssh forge.vzkn.eu -p 2222
   ```
4. First login — install tooling via home-manager:
   ```sh
   nix run home-manager -- switch \
     --flake github:vrozaksen/nix-config#vrozaksen-forge
   ```
5. Copy your git ssh key once for forgejo/github push:
   ```sh
   scp ~/.ssh/id_ed25519 forge.vzkn.eu:~/.ssh/   # from your workstation
   ```

