terraform {
  required_version = ">= 1.6.6"

  backend "s3" {
    bucket         = "372517046622-terraform-state-dev"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "372517046622-terraform-lock-dev" # optional, for state locking
  }
}