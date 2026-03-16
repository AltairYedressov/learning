variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket"
}

variable "environment" {
  type        = string
  description = "Environment name e.g. dev, prod"
}

variable "versioning_enabled" {
  type        = bool
  description = "Enable versioning on the bucket"
  default     = true
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ARN for encryption. Uses AES256 if null"
  default     = null
}

variable "lifecycle_rules" {
  type = list(object({
    id              = string
    enabled         = bool
    expiration_days = optional(number)
    transitions = list(object({
      days          = number
      storage_class = string
    }))
  }))
  description = "Lifecycle rules for the bucket"
  default     = []
}

variable "cors_rules" {
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = list(string)
    max_age_seconds = number
  }))
  description = "CORS rules for the bucket"
  default     = []
}

variable "bucket_policy" {
  type        = string
  description = "Bucket policy JSON"
  default     = null
}