resource "harbor_config_auth" "oidc" {
  auth_mode          = "oidc_auth"
  primary_auth_mode  = true
  oidc_name          = "Kanidm"
  oidc_endpoint      = "https://idm.vzkn.eu/oauth2/openid/harbor"
  oidc_client_id     = data.infisical_secrets.oidc.secrets["HARBOR_CLIENT_ID"].value
  oidc_client_secret = data.infisical_secrets.oidc.secrets["HARBOR_CLIENT_SECRET"].value
  oidc_scope         = "openid,profile,email,groups"
  oidc_verify_cert   = true
  oidc_auto_onboard  = true
  oidc_user_claim    = "preferred_username"
  oidc_groups_claim  = "groups"
  oidc_admin_group   = "admins"
  oidc_logout        = true
}
