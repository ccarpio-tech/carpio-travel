terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Store state in S3 (no variables allowed here, Terraform reads this first)
  backend "s3" {
    bucket       = "carpio-travel-tfstate-457344076719"
    key          = "carpio-travel/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
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
