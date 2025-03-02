AUTHENTICATION_SOURCES = ["oauth2"]
OAUTH2_AUTO_CREATE_USER = True
MASTER_PASSWORD_REQUIRED = False
OAUTH2_CONFIG = [{
    "OAUTH2_NAME": "authentik",
    "OAUTH2_DISPLAY_NAME": "Login with Authentik",
    'OAUTH2_CLIENT_ID': '{{ .PGADMIN_CLIENT_ID }}',
    'OAUTH2_CLIENT_SECRET': '{{ .PGADMIN_CLIENT_SECRET }}',
    "OAUTH2_TOKEN_URL": "https://sso.vzkn.eu/application/o/token/",
    "OAUTH2_AUTHORIZATION_URL": "https://sso.vzkn.eu/application/o/authorize/",
    "OAUTH2_API_BASE_URL": "https://sso.vzkn.eu/",
    "OAUTH2_USERINFO_ENDPOINT": "https://sso.vzkn.eu/application/o/userinfo/",
    "OAUTH2_SERVER_METADATA_URL": "https://sso.vzkn.eu/application/o/pgadmin/.well-known/openid-configuration",
    "OAUTH2_SCOPE": "openid email profile",
    "OAUTH2_ICON": "fa-openid",
    "OAUTH2_BUTTON_COLOR": "#2db1fd"
}]
