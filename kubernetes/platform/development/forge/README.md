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
| PVC `forge` (50Gi ceph-block, via kopiur) | `subPath: home` → `/home/vrozaksen`, `subPath: keys` → `/etc/ssh/keys`. |
| Service `forge:22` (ClusterIP) | Single service, so app-template names it after the release, not `forge-ssh`. |
| Towonel agent | TCP forward `forge.development:22` → bifrost VPS `:2222`. |
| DNSEndpoint | `forge.vzkn.eu` → VPS IP via external-dns. |
| Kopiur (Kopia) | Hourly snapshots → Garage S3 (24h/10d/5w/3m retention). |

## SSH security

- OpenSSH 9.9+ with post-quantum hybrid KEX (`mlkem768x25519-sha256`).
- Pubkey auth only — no password, no PAM, no challenge-response.
- `AllowUsers vrozaksen`, `MaxAuthTries 3`, `ClientAliveInterval 60`.
- Authorized keys mounted from Infisical (`/kubernetes/development/forge/AUTHORIZED_KEYS`,
  multi-line value, one pubkey per line).
- Host keys persisted on PVC — clients never see "host key changed" after restart.
- Pod runs with minimal sshd capability set, seccomp RuntimeDefault, no SA token mounted.

## Bring-up

Nothing is copied onto the volume by hand. Everything the pod needs beyond its
own data is either baked into the image or mounted from Infisical, so a rebuilt
or restored PVC comes back ready.

1. Populate Infisical `/kubernetes/development/forge/`:

   | Key | What |
   | --- | --- |
   | `AUTHORIZED_KEYS` | multi-line, one ssh pubkey per line — add/remove devices here |
   | `GIT_SSH_KEY` | private key for pushing to forgejo/github |
   | `KUBECONFIG` | for in-pod kubectl / flux |
   | `TALOSCONFIG` | for in-pod talosctl |

2. Flux reconciles; wait for the `forge` Deployment to be ready.
3. `ssh forge.vzkn.eu -p 2222` — the toolchain converges on its own in the
   background, progress in `~/.forge-hm.log`.

`~/.ssh/id_ed25519`, `~/.kube/config` and `~/.talos/config` are out-of-store
symlinks onto the read-only mounts, so rotating any of them in Infisical is
picked up without touching the pod.

## Claude Code from a phone (Remote Control)

Forge is the always-on host that Remote Control needs — sessions survive the
workstation sleeping. Inside a zellij session on the pod:

```sh
claude /login                             # once; OAuth creds persist on the PVC
claude remote-control --spawn worktree    # server mode, each session its own worktree
```

Then drive it from the Claude mobile app or claude.ai/code — no SSH needed.
Set `attribution` (`commit`/`pr` empty, `sessionUrl: false`) in the pod's
`~/.claude/settings.json` so commits carry no Claude trailer; best done in
`nix-config#vrozaksen-forge` so it survives a PVC rebuild.

