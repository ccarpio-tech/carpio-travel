output "s3_bucket_name" {
  description = "Name of the private S3 bucket holding the site files"
  value       = aws_s3_bucket.site.id
}

output "s3_bucket_arn" {
  description = "ARN of the site bucket (used in IAM and bucket policies)"
  value       = aws_s3_bucket.site.arn
}
