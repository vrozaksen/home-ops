locals {
  private_projects = {
    "containers" = {
      public                      = true
      vulnerability_scanning      = true
      enable_content_trust_cosign = true
      auto_sbom_generation        = true
      reuse_sys_cve_allowlist     = true
      storage_quota               = 50
    }
    "home-ops" = {
      public                      = false
      vulnerability_scanning      = true
      enable_content_trust_cosign = true
      auto_sbom_generation        = true
      reuse_sys_cve_allowlist     = true
      storage_quota               = 10
    }
  }

  # URL pattern: registry.vzkn.eu/proxy-<name>/<original-path>
  proxy_registries = {
    "dockerhub"  = { endpoint_url = "https://hub.docker.com",          provider_name = "docker-hub" }
    "ghcr"       = { endpoint_url = "https://ghcr.io",                 provider_name = "github" }
    "quay"       = { endpoint_url = "https://quay.io",                 provider_name = "quay" }
    "gcr"        = { endpoint_url = "https://gcr.io",                  provider_name = "google-gcr" }
    "k8s"        = { endpoint_url = "https://registry.k8s.io",         provider_name = "docker-registry" }
    "ecr-public" = { endpoint_url = "https://public.ecr.aws",          provider_name = "aws-ecr" }
    "mcr"        = { endpoint_url = "https://mcr.microsoft.com",       provider_name = "docker-registry" }
    "nvcr"       = { endpoint_url = "https://nvcr.io",                 provider_name = "docker-registry" }
    "cgr"        = { endpoint_url = "https://cgr.dev",                 provider_name = "docker-registry" }
    "registry1"  = { endpoint_url = "https://registry1.docker.io",     provider_name = "docker-registry" }
  }
}

resource "harbor_project" "private" {
  for_each = local.private_projects

  name                        = each.key
  public                      = each.value.public
  vulnerability_scanning      = each.value.vulnerability_scanning
  enable_content_trust_cosign = each.value.enable_content_trust_cosign
  auto_sbom_generation        = each.value.auto_sbom_generation
  reuse_sys_cve_allowlist     = each.value.reuse_sys_cve_allowlist
  storage_quota               = each.value.storage_quota
}

resource "harbor_registry" "upstream" {
  for_each = local.proxy_registries

  name          = "upstream-${each.key}"
  endpoint_url  = each.value.endpoint_url
  provider_name = each.value.provider_name
}

resource "harbor_project" "proxy" {
  for_each = local.proxy_registries

  name                    = "proxy-${each.key}"
  public                  = true
  registry_id             = harbor_registry.upstream[each.key].registry_id
  vulnerability_scanning  = false
  reuse_sys_cve_allowlist = true
  storage_quota           = 50
}
