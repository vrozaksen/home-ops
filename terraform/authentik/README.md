<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_authentik"></a> [authentik](#requirement\_authentik) | ~> 2025.6.0 |
| <a name="requirement_bitwarden"></a> [bitwarden](#requirement\_bitwarden) | >= 0.11.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_authentik"></a> [authentik](#provider\_authentik) | 2025.6.0 |
| <a name="provider_bitwarden"></a> [bitwarden](#provider\_bitwarden) | 0.14.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_oauth2-gitea"></a> [oauth2-gitea](#module\_oauth2-gitea) | ./oauth2_application | n/a |
| <a name="module_oauth2-grafana"></a> [oauth2-grafana](#module\_oauth2-grafana) | ./oauth2_application | n/a |
| <a name="module_oauth2-headlamp"></a> [oauth2-headlamp](#module\_oauth2-headlamp) | ./oauth2_application | n/a |
| <a name="module_oauth2-karakeep"></a> [oauth2-karakeep](#module\_oauth2-karakeep) | ./oauth2_application | n/a |
| <a name="module_oauth2-mealie"></a> [oauth2-mealie](#module\_oauth2-mealie) | ./oauth2_application | n/a |
| <a name="module_oauth2-miniflux"></a> [oauth2-miniflux](#module\_oauth2-miniflux) | ./oauth2_application | n/a |
| <a name="module_oauth2-mirotalk"></a> [oauth2-mirotalk](#module\_oauth2-mirotalk) | ./oauth2_application | n/a |
| <a name="module_oauth2-nextcloud"></a> [oauth2-nextcloud](#module\_oauth2-nextcloud) | ./oauth2_application | n/a |
| <a name="module_oauth2-open-webui"></a> [oauth2-open-webui](#module\_oauth2-open-webui) | ./oauth2_application | n/a |
| <a name="module_oauth2-outline"></a> [oauth2-outline](#module\_oauth2-outline) | ./oauth2_application | n/a |
| <a name="module_oauth2-paperless"></a> [oauth2-paperless](#module\_oauth2-paperless) | ./oauth2_application | n/a |
| <a name="module_oauth2-pgadmin"></a> [oauth2-pgadmin](#module\_oauth2-pgadmin) | ./oauth2_application | n/a |
| <a name="module_oauth2-rresume"></a> [oauth2-rresume](#module\_oauth2-rresume) | ./oauth2_application | n/a |
| <a name="module_oauth2-vikunja"></a> [oauth2-vikunja](#module\_oauth2-vikunja) | ./oauth2_application | n/a |
| <a name="module_oauth2-zipline"></a> [oauth2-zipline](#module\_oauth2-zipline) | ./oauth2_application | n/a |
| <a name="module_proxy-bazarr"></a> [proxy-bazarr](#module\_proxy-bazarr) | ./proxy_application | n/a |
| <a name="module_proxy-prowlarr"></a> [proxy-prowlarr](#module\_proxy-prowlarr) | ./proxy_application | n/a |
| <a name="module_proxy-radarr"></a> [proxy-radarr](#module\_proxy-radarr) | ./proxy_application | n/a |
| <a name="module_proxy-sonarr"></a> [proxy-sonarr](#module\_proxy-sonarr) | ./proxy_application | n/a |

## Resources

| Name | Type |
|------|------|
| [authentik_brand.default](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/brand) | resource |
| [authentik_brand.home](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/brand) | resource |
| [authentik_flow.authentication](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow) | resource |
| [authentik_flow.authenticator-totp-setup](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow) | resource |
| [authentik_flow.authenticator-webauthn-setup](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow) | resource |
| [authentik_flow.enrollment-invitation](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow) | resource |
| [authentik_flow.invalidation](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow) | resource |
| [authentik_flow.passwordless_authentication](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow) | resource |
| [authentik_flow.provider-authorization-implicit-consent](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow) | resource |
| [authentik_flow.provider-invalidation](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow) | resource |
| [authentik_flow.recovery](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow) | resource |
| [authentik_flow.user-settings](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow) | resource |
| [authentik_flow_stage_binding.authentication-flow-binding-00](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.authentication-flow-binding-10](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.authentication-flow-binding-100](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.authenticator-totp-setup-binding-00](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.authenticator-webauthn-setup-binding-00](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.enrollment-invitation-flow-binding-00](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.enrollment-invitation-flow-binding-10](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.enrollment-invitation-flow-binding-20](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.enrollment-invitation-flow-binding-30](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.invalidation-flow-binding-00](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.passwordless_authentication-binding-00](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.passwordless_authentication-binding-10](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.recovery-flow-binding-00](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.recovery-flow-binding-10](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.recovery-flow-binding-20](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.recovery-flow-binding-30](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.user-settings-flow-binding-100](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_flow_stage_binding.user-settings-flow-binding-20](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding) | resource |
| [authentik_group.admin](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/group) | resource |
| [authentik_group.grafana_admin](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/group) | resource |
| [authentik_group.home](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/group) | resource |
| [authentik_group.infrastructure](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/group) | resource |
| [authentik_group.media](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/group) | resource |
| [authentik_group.nextcloudAdmin](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/group) | resource |
| [authentik_group.public](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/group) | resource |
| [authentik_group.superusers](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/group) | resource |
| [authentik_group.users](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/group) | resource |
| [authentik_outpost.proxyoutpost](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/outpost) | resource |
| [authentik_policy_binding.github_superusers_only](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/policy_binding) | resource |
| [authentik_policy_expression.user-settings-authorization](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/policy_expression) | resource |
| [authentik_policy_password.password-complexity](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/policy_password) | resource |
| [authentik_property_mapping_provider_scope.openid-nextcloud](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/property_mapping_provider_scope) | resource |
| [authentik_service_connection_kubernetes.local](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/service_connection_kubernetes) | resource |
| [authentik_source_oauth.github](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/source_oauth) | resource |
| [authentik_stage_authenticator_totp.authenticator-totp-setup](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_authenticator_totp) | resource |
| [authentik_stage_authenticator_validate.authentication-mfa-validation](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_authenticator_validate) | resource |
| [authentik_stage_authenticator_validate.authentication-passkey-validation](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_authenticator_validate) | resource |
| [authentik_stage_authenticator_webauthn.authenticator-webauthn-setup](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_authenticator_webauthn) | resource |
| [authentik_stage_email.recovery-email](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_email) | resource |
| [authentik_stage_identification.authentication-identification](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_identification) | resource |
| [authentik_stage_identification.recovery-identification](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_identification) | resource |
| [authentik_stage_invitation.enrollment-invitation](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_invitation) | resource |
| [authentik_stage_password.authentication-password](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_password) | resource |
| [authentik_stage_prompt.password-change-prompt](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_prompt) | resource |
| [authentik_stage_prompt.source-enrollment-prompt](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_prompt) | resource |
| [authentik_stage_prompt.user-settings](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_prompt) | resource |
| [authentik_stage_prompt_field.email](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_prompt_field) | resource |
| [authentik_stage_prompt_field.locale](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_prompt_field) | resource |
| [authentik_stage_prompt_field.name](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_prompt_field) | resource |
| [authentik_stage_prompt_field.password](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_prompt_field) | resource |
| [authentik_stage_prompt_field.password-repeat](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_prompt_field) | resource |
| [authentik_stage_prompt_field.username](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_prompt_field) | resource |
| [authentik_stage_user_login.authentication-login](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_user_login) | resource |
| [authentik_stage_user_login.source-enrollment-login](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_user_login) | resource |
| [authentik_stage_user_logout.invalidation-logout](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_user_logout) | resource |
| [authentik_stage_user_write.enrollment-user-write](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_user_write) | resource |
| [authentik_stage_user_write.password-change-write](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_user_write) | resource |
| [authentik_stage_user_write.user-settings-write](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/stage_user_write) | resource |
| [authentik_brand.authentik-default](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/brand) | data source |
| [authentik_certificate_key_pair.generated](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/certificate_key_pair) | data source |
| [authentik_flow.default-brand-authentication](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/flow) | data source |
| [authentik_flow.default-brand-invalidation](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/flow) | data source |
| [authentik_flow.default-brand-user-settings](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/flow) | data source |
| [authentik_flow.default-source-authentication](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/flow) | data source |
| [authentik_group.admins](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/group) | data source |
| [bitwarden_secret.application](https://registry.terraform.io/providers/maxlaverse/bitwarden/latest/docs/data-sources/secret) | data source |
| [bitwarden_secret.authentik](https://registry.terraform.io/providers/maxlaverse/bitwarden/latest/docs/data-sources/secret) | data source |
| [bitwarden_secret.github](https://registry.terraform.io/providers/maxlaverse/bitwarden/latest/docs/data-sources/secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bw_access_token"></a> [bw\_access\_token](#input\_bw\_access\_token) | Bitwarden Secret Manager Access token | `string` | n/a | yes |
| <a name="input_cluster_domain"></a> [cluster\_domain](#input\_cluster\_domain) | Domain for Authentik | `string` | `"vzkn.eu"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
