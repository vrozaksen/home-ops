resource "harbor_config_auth" "oidc" {
  auth_mode          = "oidc_auth"
  primary_auth_mode  = true
  oidc_name          = "Authentik"
  oidc_endpoint      = "https://sso.vzkn.eu/application/o/harbor/"
  oidc_client_id     = data.infisical_secrets.harbor_admin.secrets["HARBOR_OIDC_CLIENT_ID"].value
  oidc_client_secret = data.infisical_secrets.harbor_admin.secrets["HARBOR_OIDC_CLIENT_SECRET"].value
  oidc_scope         = "openid,profile,email"
  oidc_verify_cert   = true
  oidc_auto_onboard  = true
  oidc_user_claim    = "preferred_username"
  oidc_groups_claim  = "groups"
  oidc_admin_group   = "admin"
  oidc_logout        = true
}
