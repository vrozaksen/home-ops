module "secrets" {
  for_each   = toset(local.buckets)
  source     = "./modules/create-secret"
  name       = "${each.key}-bucket"
  username   = module.buckets[each.key].access_key_id
  password   = module.buckets[each.key].access_key_secret
  bw_proj_id = data.bitwarden_secret.bw_proj_id.value
}

resource "bitwarden_secret" "admin_user" {
  key        = "garage-admin"
  note       = "Token for garage admin"
  project_id = data.bitwarden_secret.bw_proj_id.value
  value      = "AWS_ACCESS_KEY_ID: ${garage_key.admin_key.access_key_id}\nAWS_SECRET_ACCESS_KEY: ${garage_key.admin_key.secret_access_key}"
}
