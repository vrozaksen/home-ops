# ─────────────────────────────────────────────────────────────────────────────────
# State migration — drop old bitwarden resources (provider removed)
# Safe to delete these blocks after first successful apply
# ─────────────────────────────────────────────────────────────────────────────────

removed {
  from = module.secrets
  lifecycle {
    destroy = false
  }
}

removed {
  from = bitwarden_secret.admin_user
  lifecycle {
    destroy = false
  }
}

# ─────────────────────────────────────────────────────────────────────────────────

resource "infisical_secret" "bucket_access_key_id" {
  for_each     = toset(local.buckets)
  name         = "${upper(replace(each.key, "-", "_"))}_ACCESS_KEY_ID"
  value        = module.buckets[each.key].access_key_id
  env_slug     = "prod"
  workspace_id = "da94b011-9a7d-408b-92d9-55be47efe750"
  folder_path  = "/terraform/garage/buckets"
}

resource "infisical_secret" "bucket_secret_access_key" {
  for_each     = toset(local.buckets)
  name         = "${upper(replace(each.key, "-", "_"))}_SECRET_ACCESS_KEY"
  value        = module.buckets[each.key].access_key_secret
  env_slug     = "prod"
  workspace_id = "da94b011-9a7d-408b-92d9-55be47efe750"
  folder_path  = "/terraform/garage/buckets"
}

resource "infisical_secret" "admin_access_key_id" {
  name         = "GARAGE_ADMIN_ACCESS_KEY_ID"
  value        = garage_key.admin_key.access_key_id
  env_slug     = "prod"
  workspace_id = "da94b011-9a7d-408b-92d9-55be47efe750"
  folder_path  = "/terraform/garage"
}

resource "infisical_secret" "admin_secret_access_key" {
  name         = "GARAGE_ADMIN_SECRET_ACCESS_KEY"
  value        = garage_key.admin_key.secret_access_key
  env_slug     = "prod"
  workspace_id = "da94b011-9a7d-408b-92d9-55be47efe750"
  folder_path  = "/terraform/garage"
}
