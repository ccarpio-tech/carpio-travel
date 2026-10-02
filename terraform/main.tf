# Look up the current AWS account ID (read-only, creates nothing).
data "aws_caller_identity" "current" {}

locals {
  # S3 bucket names are globally unique, so suffix with the account ID.
  bucket_name = "${var.project_name}-site-${data.aws_caller_identity.current.account_id}"
}

# ------------------------------------------------------------------------------
# S3 origin bucket (private; only CloudFront will be allowed to read it)
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name

  # Allows `terraform destroy` to delete the bucket even when it contains site
  # files. Convenient for a portfolio environment; remove for production.
  force_destroy = true
}

# Block every form of public access (ACLs and bucket policies).
resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Disable ACLs entirely; access is controlled only by the bucket policy.
resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Encrypt objects at rest with S3-managed keys (SSE-S3).
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
