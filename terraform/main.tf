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

# ------------------------------------------------------------------------------
# CloudFront Origin Access Control (CloudFront signs its requests to S3)
# ------------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_name}-oac"
  description                       = "Lets CloudFront read the private ${local.bucket_name} bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ------------------------------------------------------------------------------
# CloudFront distribution
# ------------------------------------------------------------------------------

# AWS-managed cache policy, looked up by name rather than hardcoding its ID.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} static site"
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # North America + Europe edges only

  origin {
    # REST endpoint (not the S3 website endpoint), required for OAC.
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${local.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${local.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Default *.cloudfront.net certificate for now; replaced by ACM in V2.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# ------------------------------------------------------------------------------
# Bucket policy: allow reads only from this CloudFront distribution
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "site_bucket" {
  statement {
    sid       = "AllowCloudFrontOACRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_bucket.json

  # Apply the policy after Block Public Access is in place.
  depends_on = [aws_s3_bucket_public_access_block.site]
}
