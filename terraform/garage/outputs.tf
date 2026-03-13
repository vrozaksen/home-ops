output "secrets" {
  value = {
    for bucket in local.buckets : bucket => {
      id = infisical_secret.bucket_access_key_id[bucket].id
    }
  }
}
