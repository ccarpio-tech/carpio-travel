data "aws_caller_identity" "current" {}

locals {
  # Bucket names are global (account ID suffix keeps it unique)
  bucket_name = "${var.project_name}-site-${data.aws_caller_identity.current.account_id}"
}

# S3 bucket for the site files (private; only CloudFront can read it)
resource "aws_s3_bucket" "site" {
  bucket = local.bucket_name

  # Lets `terraform destroy` delete it with files still inside
  # (fine for a portfolio, remove for production)
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Turn off ACLs (access is controlled only by the bucket policy)
resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudFront Origin Access Control (CloudFront signs its requests to S3)
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_name}-oac"
  description                       = "Lets CloudFront read the private ${local.bucket_name} bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# AWS-managed cache policy (looked up by name instead of hardcoding the ID)
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} static site"
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # North America + Europe edges only (cheapest)

  # Domains CloudFront answers for (each must be on the ACM cert)
  aliases = [var.domain_name, "www.${var.domain_name}"]

  origin {
    # S3 REST endpoint (not the website endpoint, which OAC doesn't support)
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

  viewer_certificate {
    # Use the validation waiter, not the cert (so CloudFront only gets an issued cert)
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"     # free ("vip" is $600/month)
    minimum_protocol_version = "TLSv1.2_2021" # TLS 1.2+ only (no 1.0/1.1)
  }
}

# Bucket policy (only this CloudFront distribution can read objects)
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

  # Apply after Block Public Access (avoids S3 conflict errors if both change at once)
  depends_on = [aws_s3_bucket_public_access_block.site]
}
