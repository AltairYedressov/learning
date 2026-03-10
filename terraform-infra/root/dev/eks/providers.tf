# terraform-infra/root/dev/eks/providers.tf
terraform {
  required_version = ">= 1.6.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100" # ← matches your lock file exactly
    }
    flux = {
      source  = "fluxcd/flux"
      version = "~> 1.8"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.11"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
