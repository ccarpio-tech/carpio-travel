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

variable "domain_name" {
  description = "Apex domain registered in Route 53"
  type        = string
  default     = "carpiotravel.com"
}

variable "github_repo" {
  description = "GitHub owner@id/repo@id as it appears in the OIDC token"
  type        = string
  default     = "ccarpio-tech@287112669/carpio-travel@1402034081"
}

variable "github_branch" {
  description = "GitHub branch name"
  type        = string
  default     = "main"
}