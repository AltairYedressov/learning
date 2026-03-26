variable "domain_name" {
  type        = string
  description = "Primary domain name for the certificate"
}

variable "subject_alternative_names" {
  type        = list(string)
  description = "Additional domain names for the certificate"
  default     = []
}

variable "zone_id" {
  type        = string
  description = "Route 53 hosted zone ID for DNS validation"
}

variable "environment" {
  type = string
}
