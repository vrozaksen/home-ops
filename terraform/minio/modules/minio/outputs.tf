output "bucket_name" {
  description = "The name of the created S3 bucket"
  value       = minio_s3_bucket.bucket.bucket
}

output "bucket_arn" {
  description = "The ARN of the created S3 bucket"
  value       = "arn:aws:s3:::${minio_s3_bucket.bucket.bucket}"
}

output "user_name" {
  description = "The name of the IAM user"
  value       = minio_iam_user.user.name
}

output "user_access_key" {
  description = "The access key for the IAM user"
  value       = minio_iam_user.user.name
  sensitive   = true
}

output "user_secret_key" {
  description = "The secret key for the IAM user"
  value       = minio_iam_user.user.secret
  sensitive   = true
}

output "policy_name" {
  description = "The name of the IAM policy"
  value       = minio_iam_policy.policy.name
}
