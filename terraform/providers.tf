terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# No credentials here (locally it uses the AWS CLI login,
# in GitHub Actions it uses short-lived OIDC credentials)
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Repo      = "github.com/ccarpio-tech/carpio-travel"
    }
  }
}
