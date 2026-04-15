variable "environment" {
  description = "Environment tag"
  type        = string
}

variable "ecr_names" {
  description = "List of ECR repository names"
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "ECR image tag mutability"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "ECR image scanning on push"
  type        = bool
  default     = true
}

variable "immutable_repos" {
  description = "Subset of ecr_names that should be IMMUTABLE regardless of image_tag_mutability default."
  type        = list(string)
  default     = []
}
