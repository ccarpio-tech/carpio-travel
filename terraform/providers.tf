terraform {
  # Minimum Terraform CLI version this configuration is tested with.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # any 6.x release, never 7.0 (major versions can have breaking changes)
    }
  }
}

# Credentials are NOT configured here. The provider uses the standard AWS
# credential chain: locally that's the AWS CLI login session / profile, and in
# GitHub Actions it's short-lived credentials from OIDC.
provider "aws" {
  region = var.aws_region

  # Applied to every taggable resource this provider creates.
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Repo      = "github.com/ccarpio-tech/carpio-travel"
    }
  }
}
