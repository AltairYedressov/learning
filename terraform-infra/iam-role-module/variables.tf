variable "role_name" {
  description = "IAM role name"
  type        = string
}

variable "environment" {
  description = "Environment tag"
  type        = string
}

variable "principal_type" {
  description = "AWS | Service | Federated"
  type        = string
}

variable "principal_identifiers" {
  description = "List of ARNs or services that can assume the role"
  type        = list(string)
}

variable "assume_role_conditions" {
  description = "Optional conditions for assume role"
  type = map(object({
    test     = string
    variable = string
    values   = list(string)
  }))
  default = {}
}

variable "custom_policy_json_path" {
  description = "Path to custom policy JSON file (optional)"
  type        = string
  default     = null
}

variable "aws_managed_policy_arns" {
  description = "List of AWS managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary ARN"
  type        = string
  default     = "arn:aws:iam::372517046622:policy/TerraformPermissionBoundary"
}