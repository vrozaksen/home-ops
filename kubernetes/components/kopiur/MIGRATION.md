# Volsync → Kopiur Migration

The volsync (perfectra1n fork) repo on `aincrad.home.vzkn.eu:/mnt/blaze/volsync-kopia`
**is** a native kopia repository. Kopiur adopts it in place (`Repository/volsync` in
`kopiur-system`) and `RepositoryReplication/volsync-to-garage` blob-copies it into the
`kopiur` Garage bucket — same history, same `KOPIA_PASSWORD`. Apps then back up to
`ClusterRepository/garage` with identity pinned to the fork convention
(`<app>@<namespace>:/data`), so retention sees old and new snapshots as one series.

## Phases

1. **Deploy** (this PR): terraform garage bucket, Infisical folder
   `/kubernetes/kopiur-system/kopiur` with Secret Imports (`/shared/volsync` +
   `/terraform/garage/buckets`), operator, adopted `Repository/volsync`,
   replication, `ClusterRepository/garage`.
2. **Seed**: wait for the first replication run to succeed and
   `ClusterRepository/garage` to reach `Ready`. Old snapshots surface as
   `origin: discovered` in `kopiur-system`.
3. **Cut over apps** one by one (below), starting with something low-stakes
   (e.g. metube, atuin).
4. **Retire**: when no app uses `components/volsync` — delete
   `core/storage/volsync` (HR, maintenance, MutatingAdmissionPolicy),
   `components/volsync`, `.taskfiles/volsync`, the replication CR, and flip
   `Repository/volsync` to `mode: ReadOnly` (or delete it). Enable
   `maintenance` on `Repository/volsync` only if it stays. **Keep the
   `KOPIA_PASSWORD` secret in Infisical forever.** Repoint or remove the kopia
   web UI (`core/storage/kopia`).

## Per-app cutover

A bound PVC's `dataSourceRef` is immutable (volsync: `ReplicationDestination`,
kopiur: `Restore`), so the PVC must be recreated via the populator.

1. **Verify identity continuity first** (one-time, before the first app):

   ```bash
   kubectl krew install kopiur   # or grab kubectl-kopiur from the release
   kubectl get replicationsource -A -o yaml | \
     kubectl kopiur migrate volsync -f - --repository garage
   ```

   Check the `(fork snapshot identity)` lines match what
   `components/kopiur` pins (`<app>@<namespace>:/data`). Any app whose
   sanitized identity differs needs explicit `identity` overrides instead of
   the component defaults.

2. **Fresh volsync backup**: `task volsync:snapshot NS=<ns> APP=<app>`.

3. **Swap the component** in the app's `ks.yaml`:

   ```yaml
   components:
     - ../../../components/kopiur      # was: components/volsync
   postBuild:
     substitute:
       APP: *app
       NS: &ns <namespace>
       KOPIUR_CAPACITY: 5Gi            # was: VOLSYNC_CAPACITY
   ```

   Variables map 1:1: `VOLSYNC_*` → `KOPIUR_*` (`CAPACITY`, `STORAGECLASS`,
   `ACCESSMODES`, `SNAPSHOTCLASS`, `CACHE_CAPACITY`, `SCHEDULE`, `PUID`, `PGID`).

4. **Push and let it fail forward**: Flux prunes the volsync CRs and errors on
   the PVC (immutable `dataSourceRef`) — expected. The replication cron
   (every 6h) carries the last volsync snapshot to garage; either wait for it
   or take a manual kopiur snapshot later. Then:

   ```bash
   kubectl -n <ns> scale deploy/<app> --replicas=0
   kubectl -n <ns> delete pvc <app>
   flux reconcile ks <app> -n flux-system --with-source
   # Restore populator hydrates the new PVC from the latest garage snapshot
   kubectl -n <ns> get restore <app> -w
   kubectl -n <ns> scale deploy/<app> --replicas=1
   ```

5. **Prove continuity**: force a snapshot and check it extends the old series:

   ```bash
   kubectl kopiur snapshot now --policy <app> -n <ns> --wait
   kubectl kopiur snapshots list -n <ns>
   ```

   The new snapshot must dedup (small `bytesNew`), not re-upload the full PVC.

## Gotchas

- Cutover order within an app: volsync `ReplicationSource` must stop before
  kopiur starts snapshotting the same identity — the component swap does both
  atomically, but never run both components on one app.
- The replication mirror never deletes destination blobs (`sync-to` without
  `--delete`), so kopiur snapshots written to garage survive replication runs.
- Cross-namespace moves keep working: kopiur restores by identity/policy —
  see `docs/scenarios/clone-app-to-namespace.md` upstream (replaces the old
  volsync MIGRATION.md dance).
- `task talos:reboot-node` still does volsync suspend/resume; keep it until
  retirement, then update `.taskfiles/talos`.
