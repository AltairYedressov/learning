variable "environment" {
  description = "Environment tag"
  type        = string
}

variable "ecr_name" {
  description = "ECR repository name"
  type        = string
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
