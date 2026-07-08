# Kopiur backups — component notes

Migrated from volsync (perfectra1n kopia fork) on 2026-07-08. The old NFS repo
was adopted in place and blob-replicated (`kopia repository sync-to`) into the
`kopiur` Garage bucket — full history and the same `KOPIA_PASSWORD` carried over.

## How this component behaves

- `SnapshotPolicy` pins identity to `<app>@<namespace>:/data` (the volsync fork
  convention) so pre-migration history and new snapshots form one series.
- `PVC` + passive `Restore` populator = deploy-or-restore: a fresh claim
  hydrates from the latest snapshot for that identity (resolved directly in the
  repository — no `Snapshot` CRs needed); if none exists, it comes up empty
  (`onMissingSnapshot: Continue`).
- Re-enabling an archived/disabled app auto-restores its data. Point-in-time:
  set `asOf`/`offset` on a manual `Restore`, or `task kopiur:restore`.
- Pre-migration snapshots surface as `origin: discovered` with forced
  `deletionPolicy: Retain` — kopiur never deletes them; prune by hand if ever
  needed.

## Variables

`APP`, `NS` (identity!), `KOPIUR_CAPACITY`, `KOPIUR_STORAGECLASS`,
`KOPIUR_ACCESSMODES`, `KOPIUR_SNAPSHOTCLASS`, `KOPIUR_CACHE_CAPACITY`,
`KOPIUR_SCHEDULE`, `KOPIUR_PUID`, `KOPIUR_PGID`.

Root movers (`KOPIUR_PUID: "0"`, e.g. terraria) need the namespace annotation
`kopiur.home-operations.com/privileged-movers: "true"`.

## Gotchas

- A bound PVC's `dataSourceRef` is immutable — changing backup lineage means
  scale down → delete PVC → let the populator rehydrate.
- `create.enabled` on repositories must stay **false**: an absent `create`
  block defaults to TRUE in the operator and would initialize a fresh empty
  repo over a typo'd backend.
- Old NFS repo (`aincrad:/mnt/blaze/volsync-kopia`) is a frozen cold copy as of
  migration day; safe to delete once garage retention builds trust.
- Never delete `KOPIA_PASSWORD` from Infisical (`/shared/volsync`) — it
  encrypts the garage repository.
