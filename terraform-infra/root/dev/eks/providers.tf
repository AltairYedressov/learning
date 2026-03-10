terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"    # matches your lock file
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