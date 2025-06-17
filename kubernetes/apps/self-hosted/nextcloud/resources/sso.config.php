<?php
$CONFIG = array (
  'allow_user_to_change_display_name' => false,
  'lost_password_link' => 'disabled',
  'oidc_login_provider_url' => 'https://sso.vzkn.eu/application/o/nextcloud/',
  'oidc_login_client_id' => getenv('NEXTCLOUD_OAUTH_CLIENT_ID'),
  'oidc_login_client_secret' => getenv('NEXTCLOUD_OAUTH_CLIENT_SECRET'),
  'oidc_login_auto_redirect' => true,
  'oidc_login_logout_url' => 'https://sso.vzkn.eu/application/o/nextcloud/end-session/',
  'oidc_login_end_session_redirect' => true,
  'oidc_login_default_quota' => '5000000000',
  'oidc_login_button_text' => 'Authentik SSO',
  'oidc_login_hide_password_form' => true,
  'oidc_login_attributes' => array (
           'id' => 'sub',
           'name' => 'name',
           'mail' => 'email',
  ),
  'oidc_create_groups' => true,
  'oidc_login_code_challenge_method' => 'S256',
  'oidc_login_webdav_enabled' => true,
  'oidc_login_disable_registration' => false,
);
