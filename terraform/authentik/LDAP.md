# Authentik LDAP Provider

Authentik exposes an LDAP interface for applications that require LDAP authentication.

## Connection Details

| Setting | Value |
|---------|-------|
| **Host** | `ak-outpost-ldap-outpost.security.svc.cluster.local` |
| **Port** | `389` (LDAP) / `636` (LDAPS) |
| **Base DN** | `dc=ldap,dc=vzkn,dc=eu` |
| **TLS** | StartTLS or LDAPS supported |

## Bind DN Format

```
cn=<username>,ou=users,dc=ldap,dc=vzkn,dc=eu
```

### Service Account (recommended for applications)

| Setting | Value |
|---------|-------|
| **Bind DN** | `cn=ldap-service,ou=users,dc=ldap,dc=vzkn,dc=eu` |
| **Password** | Stored in Bitwarden (`authentik` → `LDAP_SERVICE_PASSWORD`) |

### User Account Example

```
cn=john,ou=users,dc=ldap,dc=vzkn,dc=eu
```

## Search Configuration

| Setting | Value |
|---------|-------|
| **User Search Base** | `ou=users,dc=ldap,dc=vzkn,dc=eu` |
| **User Search Filter** | `(cn={0})` or `(uid={0})` |
| **Group Search Base** | `ou=groups,dc=ldap,dc=vzkn,dc=eu` |
| **Group Search Filter** | `(member={0})` |

## POSIX Attributes

| Attribute | Start Number |
|-----------|--------------|
| `uidNumber` | 10000 |
| `gidNumber` | 10000 |

## User Attributes

| LDAP Attribute | Authentik Field |
|----------------|-----------------|
| `cn` | Username |
| `uid` | Username |
| `mail` | Email |
| `displayName` | Name |
| `memberOf` | Groups |
| `uidNumber` | POSIX UID |
| `gidNumber` | POSIX GID |

## Example: Application Configuration

### Emby

| Setting | Value |
|---------|-------|
| **LDAP server address** | `ak-outpost-ldap-outpost.security.svc.cluster.local` |
| **Port** | `389` |
| **SSL** | Disabled (internal cluster) |
| **Bind DN** | `cn=ldap-service,ou=users,dc=ldap,dc=vzkn,dc=eu` |
| **Bind credentials** | `LDAP_SERVICE_PASSWORD` from Bitwarden |
| **User search base** | `ou=users,dc=ldap,dc=vzkn,dc=eu` |
| **User search filter** | `(cn={0})` |

### Nextcloud

```php
'ldapHost' => 'ak-outpost-ldap-outpost.security.svc.cluster.local',
'ldapPort' => '636',
'ldapBase' => 'dc=ldap,dc=vzkn,dc=eu',
'ldapBaseUsers' => 'ou=users,dc=ldap,dc=vzkn,dc=eu',
'ldapBaseGroups' => 'ou=groups,dc=ldap,dc=vzkn,dc=eu',
```

### Generic LDAP Client

```bash
ldapsearch -x -H ldap://ak-outpost-ldap-outpost.security.svc.cluster.local \
  -b "dc=ldap,dc=vzkn,dc=eu" \
  -D "cn=admin,ou=users,dc=ldap,dc=vzkn,dc=eu" \
  -W "(objectClass=user)"
```

## MFA Support

MFA is **enabled** for LDAP binds. Users with TOTP/WebAuthn configured can append their OTP to password:

```
Password: mypassword123456
          ^^^^^^^^^^ ^^^^^^
          password   TOTP code
```

## Access Control

Access is controlled via RBAC permissions on the LDAP application. Bind the application to a group using policy bindings.

## Troubleshooting

Check outpost logs:
```bash
kubectl logs -n security -l app.kubernetes.io/name=ak-outpost-ldap-outpost
```

Test connection:
```bash
kubectl run ldap-test --rm -it --image=alpine -- sh
apk add openldap-clients
ldapwhoami -x -H ldap://ak-outpost-ldap-outpost.security.svc.cluster.local \
  -D "cn=testuser,ou=users,dc=ldap,dc=vzkn,dc=eu" -W
```
