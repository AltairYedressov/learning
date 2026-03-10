variable "vpc_cidr" {
  type = string
}
variable "project_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "k8s_version" {
  type = string
}

variable "authentication_mode" {
  type    = string
  default = "API_AND_CONFIG_MAP"
}

variable "environment" {
  type = string
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 5
}

variable "desired_capacity" {
  type    = number
  default = 3
}

variable "ec2_types" {
  type    = list(string)
  default = ["t3.medium", "t3a.medium", "t2.medium"]
}

# terraform-infra/eks-cluster/variables.tf (add these to existing)

variable "github_org" {
  description = "GitHub organization or username"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
}

variable "flux_path" {
  description = "Path in Git repo Flux will watch for this cluster"
  type        = string
  # automatically set from root module
  # e.g. clusters/dev-projectx
}