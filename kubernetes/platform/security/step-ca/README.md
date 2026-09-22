# step-ca — SSH certificate authority

Replaces the long-lived SSH key on `forge` with certificates that expire.
`step ssh login` authenticates against Kanidm (password + TOTP) and returns a
certificate valid for hours, so the second factor finally applies to SSH even
without a hardware token.

Nothing about this is post-quantum, and nothing about it needs to be: OpenSSH
has no post-quantum *signature* algorithm, for raw keys or certificates alike.
The post-quantum part is the key exchange (`mlkem768x25519-sha256`), which
forge already negotiates and which is unaffected by how you authenticate.

## Why the bootstrap is manual

The upstream chart's bootstrap job runs `step ca init` **without `--ssh`**, so
the CA it creates cannot sign SSH certificates at all. An SSH-capable PKI has
to be created out of band and handed to the chart through `existingSecrets`.

That is not a wart to automate away. This is a root of trust: the private keys
should be generated on a machine you control, looked at once, and stored where
you keep secrets — not produced by a job whose output nobody reads.

## One-time bootstrap

Run on your workstation, not in the cluster.

```sh
export STEPPATH=$(mktemp -d)                 # NOT ~/.step, keep it disposable
step ca init \
  --ssh \
  --name "vzkn.eu" \
  --dns "ca.vzkn.eu,step-ca.security.svc.cluster.local,127.0.0.1" \
  --address ":9000" \
  --provisioner "admin" \
  --with-ca-url "https://ca.vzkn.eu"
```

`--ssh` is the whole point: it additionally generates `ssh_host_ca_key` and
`ssh_user_ca_key` under `$STEPPATH/secrets`.

It prompts for two things. Deployment type: **Standalone** — the other options
attach the CA to smallstep's cloud or replace it with theirs. Then a password,
which encrypts every private key it just wrote, SSH signing keys included;
that is `CA_PASSWORD` below and there is no recovery without it.

Then put these into Infisical at `/kubernetes/security/step-ca/`:

| Infisical key | From |
| --- | --- |
| `CA_PASSWORD` | the password you chose at init |
| `PROVISIONER_PASSWORD` | the provisioner password you chose |
| `ROOT_CA_CRT` | `$STEPPATH/certs/root_ca.crt` |
| `INTERMEDIATE_CA_CRT` | `$STEPPATH/certs/intermediate_ca.crt` |
| `INTERMEDIATE_CA_KEY` | `$STEPPATH/secrets/intermediate_ca_key` |
| `SSH_USER_CA_KEY` | `$STEPPATH/secrets/ssh_user_ca_key` |
| `SSH_USER_CA_PUB` | `$STEPPATH/certs/ssh_user_ca_key.pub` |
| `SSH_HOST_CA_KEY` | `$STEPPATH/secrets/ssh_host_ca_key` |
| `SSH_HOST_CA_PUB` | `$STEPPATH/certs/ssh_host_ca_key.pub` |

`SSH_USER_CA_PUB` is the only one that leaves the CA: `forge` trusts it via
`TrustedUserCAKeys`, which is what makes certificates signed by this CA count
as valid logins.

Then `rm -rf "$STEPPATH"`.

## Client

Installs into the user's home directory, no administrator rights:

```powershell
scoop bucket add smallstep https://github.com/smallstep/scoop-bucket.git
scoop install smallstep/step
```

```sh
step ca bootstrap --ca-url https://ca.vzkn.eu --fingerprint <root fingerprint>
step ssh login vrozaksen@vzkn.eu --provisioner kanidm
ssh forge.vzkn.eu -p 2222        # the agent now holds a certificate
```

The certificate lands in `ssh-agent` and expires on its own. Revocation is
disabling the account in Kanidm — no secret to rotate, no pod to restart.

## The fallback stays

`forge` keeps `AuthorizedKeysFile` alongside `TrustedUserCAKeys` on purpose.
An internet-facing box whose only way in is a CA you just deployed is one
misconfiguration away from locking you out of your own workstation. Drop the
`authorized_keys` path only once certificate login has actually worked, and
delete `AUTHORIZED_KEYS` from Infisical at the same time — not before.

## Wiring forge to the CA (after bootstrap)

Two lines that cannot land before the CA exists, because mounting a secret key
that has no value keeps the pod in ContainerCreating — and forge uses the
`Recreate` strategy, so the running pod is destroyed first.

`forge/infisicalsecret.yaml`, under `data:`

```yaml
          ssh_user_ca_pub: '{{ .SSH_USER_CA_PUB.Value }}'
```

`forge/helmrelease.yaml`, under the `credentials` mounts

```yaml
              - path: /etc/ssh/ca/ssh_user_ca_key.pub
                subPath: ssh_user_ca_pub
                readOnly: true
```

Until then the image's entrypoint leaves an empty trust file there, so sshd
starts and simply trusts no certificates.
