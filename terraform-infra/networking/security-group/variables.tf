variable "name" {
  type        = string
  description = "Security group name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where security group will be created"
}

variable "description" {
  type    = string
  default = "Managed by Terraform"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "rules" {
  type = list(object({
    cidr       = string
    from_port  = number
    to_port    = number
    protocol   = optional(string, "tcp")
    ip_version = optional(string, "ipv4")
  }))
  default = []
}

variable "egress_rules" {
  type = list(object({
    cidr       = string
    from_port  = number
    to_port    = number
    protocol   = optional(string, "tcp")
    ip_version = optional(string, "ipv4")
  }))
  default     = []
  description = "List of egress rules for the security group. Empty list means no explicit egress."
}

variable "environment" {
  type = string
}
