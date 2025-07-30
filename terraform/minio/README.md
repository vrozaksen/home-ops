<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_bitwarden"></a> [bitwarden](#requirement\_bitwarden) | >= 0.11.0 |
| <a name="requirement_minio"></a> [minio](#requirement\_minio) | 3.6.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.7.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_bitwarden"></a> [bitwarden](#provider\_bitwarden) | 0.14.0 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_buckets"></a> [buckets](#module\_buckets) | ./modules/minio | n/a |
| <a name="module_secrets"></a> [secrets](#module\_secrets) | ./modules/create-secret | n/a |

## Resources

| Name | Type |
|------|------|
| [random_password.user_name](https://registry.terraform.io/providers/hashicorp/random/3.7.2/docs/resources/password) | resource |
| [random_password.user_secret](https://registry.terraform.io/providers/hashicorp/random/3.7.2/docs/resources/password) | resource |
| [bitwarden_secret.bw_proj_id](https://registry.terraform.io/providers/maxlaverse/bitwarden/latest/docs/data-sources/secret) | data source |
| [bitwarden_secret.minio](https://registry.terraform.io/providers/maxlaverse/bitwarden/latest/docs/data-sources/secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bw_access_token"></a> [bw\_access\_token](#input\_bw\_access\_token) | Bitwarden Secret Manager Access token | `string` | n/a | yes |
| <a name="input_minio_url"></a> [minio\_url](#input\_minio\_url) | Minio Server URL | `string` | `"s3.vzkn.eu"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_secrets"></a> [secrets](#output\_secrets) | n/a |
<!-- END_TF_DOCS -->
