# CNPG Initdb Component

This component adds the `initdb` bootstrap method to a CNPG cluster.

## What it does

Patches the cluster spec to add:
```yaml
spec:
  bootstrap:
    initdb:
      database: ${CNPG_DATABASE:=${APP}}
      owner: ${CNPG_USER:=${APP}}
```

## Usage

This component is automatically included by:
- `cnpg/backup` - For new databases with backups
- `cnpg/no-backup` - For new databases without backups

**Do NOT use with:**
- `cnpg/restore` - Uses `recovery` bootstrap instead

## Variables

- `CNPG_DATABASE` - Database name (default: `${APP}`)
- `CNPG_USER` - Database owner username (default: `${APP}`)

## Generated Resources

CNPG automatically creates:
- Database user with secure random password
- Database owned by that user
- Secret `postgres-${APP}-app` with connection credentials
