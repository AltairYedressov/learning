variable "cluster_name" {
  type = string
}

variable "k8s_version" {
  type    = string
  default = "1.35"
}

variable "environment" {
  type = string
}

variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "github_org" {
  description = "GitHub org or username"
  type        = string
  # no default - passed from CI/CD
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  # no default - passed from CI/CD
}

variable "github_token" {
  description = "GitHub token for Flux bootstrap"
  type        = string
  sensitive   = true
  # no default - passed from CI/CD
}