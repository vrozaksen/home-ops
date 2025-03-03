## Standalone
#### This one will use whole "secret" as secret.
```yaml
---
# yaml-language-server: $schema=https://kube-schemas.pages.dev/external-secrets.io/externalsecret_v1beta1.json
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: &name app-secret
spec:
  secretStoreRef:
    name: bitwarden-store
    kind: ClusterSecretStore
  refreshInterval: 15m
  target:
    name: *name
  data:
  - secretKey: env
    remoteRef:
      key: bitwarden_name
```


## Template
#### This one can use one of these:
```yaml
key1: value1
key2: value2
```
```json
{
"key1":"value1",
"key2":"value2"
}
```
```yaml
---
# yaml-language-server: $schema=https://kube-schemas.pages.dev/external-secrets.io/externalsecret_v1beta1.json
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: &name app-secret
spec:
  secretStoreRef:
    name: bitwarden
    kind: ClusterSecretStore
  target:
    name: *name
    template:
      data:
        env1: '{{ .key1 }}'
        env2: '{{ .key2 }}'
  dataFrom:
    - extract:
        key: bitwarden_name
```
