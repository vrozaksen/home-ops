# Volsync Cross-Namespace Migration

Kopia snapshots are stored with identity `{app}@{namespace}`. When moving an app to a different namespace, the mover won't find snapshots under the new identity.

## Steps

1. **Snapshot before moving** - create a fresh backup in the old namespace:

   ```bash
   task volsync:snapshot NS=old-ns APP=myapp
   ```

2. **Remove app from old namespace** - delete from the old namespace kustomization and push. Flux will prune the app resources.

3. **Ensure volsync-secret exists in new namespace** - either copy from another app or wait for the ExternalSecret to be created:

   ```bash
   kubectl get secret other-app-volsync-secret -n new-ns -o json \
     | jq 'del(.metadata.uid,.metadata.resourceVersion,.metadata.creationTimestamp,.metadata.managedFields,.metadata.annotations,.metadata.labels,.metadata.ownerReferences) | .metadata.name = "myapp-volsync-secret"' \
     | kubectl apply -n new-ns -f -
   ```

4. **Create a one-off ReplicationDestination** pointing to the old namespace identity:

   ```bash
   kubectl apply -f - <<'EOF'
   apiVersion: volsync.backube/v1alpha1
   kind: ReplicationDestination
   metadata:
     name: myapp-dst
     namespace: new-ns
   spec:
     trigger:
       manual: restore-once
     kopia:
       accessModes: [ReadWriteOnce]
       capacity: 2Gi
       copyMethod: Snapshot
       enableFileDeletion: true
       moverSecurityContext:
         runAsUser: 1000
         runAsGroup: 100
         fsGroup: 100
       repository: myapp-volsync-secret
       sourceIdentity:
         sourceName: myapp
         sourceNamespace: old-ns
       storageClassName: ceph-block
       volumeSnapshotClassName: csi-ceph-blockpool
   EOF
   ```

5. **Wait for restore to complete**:

   ```bash
   kubectl get replicationdestination myapp-dst -n new-ns -o jsonpath='{.status.latestMoverStatus}'
   # Should show: {"logs":"...","result":"Successful"}
   ```

6. **Deploy the app in the new namespace** - uncomment in kustomization.yaml and push. The app will use the restored PVC.

7. **New backups** will automatically use `{app}@{new-ns}` identity going forward.

## Important Notes

- Do NOT try to use Flux Kustomization `patches` on the ReplicationDestination - the `IfNotPresent` SSA label and component ordering make this unreliable. Create the ReplicationDestination manually instead.
- The old PVC in the previous namespace can be deleted after confirming the app works in the new namespace.
- Kopia discovery mode (`kopia snapshot list --all`) can be used to verify snapshot identities if troubleshooting is needed.
