variable "aws_region" {
  description = "Primary AWS region for regional resources (S3, etc.)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for tagging and resource naming"
  type        = string
  default     = "carpio-travel"
}
