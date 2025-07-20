terraform {
  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = "~> 3.6.0"
    }
  }
}

resource "minio_s3_bucket" "this" {
  bucket = var.bucket_name
  acl    = "private"
}

resource "minio_s3_bucket_versioning" "this" {
  depends_on = [minio_s3_bucket.this]
  bucket     = minio_s3_bucket.this.bucket
  versioning_configuration {
    status = "Enabled"
  }
  count = var.versioning ? 1 : 0
}

resource "minio_iam_user" "this" {
  name   = var.user_name
  secret = var.user_secret
}

resource "minio_iam_policy" "this" {
  name   = "${var.bucket_name}-policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::${minio_s3_bucket.this.bucket}",
                "arn:aws:s3:::${minio_s3_bucket.this.bucket}/*"
            ],
            "Sid": ""
        }
    ]
}
EOF
}

resource "minio_iam_user_policy_attachment" "this" {
  user_name   = minio_iam_user.this.id
  policy_name = minio_iam_policy.this.id
}
