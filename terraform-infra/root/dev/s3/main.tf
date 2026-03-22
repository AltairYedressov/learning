module "velero_bucket" {
  source = "../../../s3"

  bucket_name = "372517046622-velero-backups-dev"
  environment = var.environment

  versioning_enabled = true

  lifecycle_rules = [
    {
      id              = "expire-old-backups"
      enabled         = true
      expiration_days = 30 # delete backups older than 30 days
      transitions     = []
    }
  ]
}

module "thanos_bucket" {
  source = "../../../s3"

  bucket_name = "372517046622-thanos-dev"
  environment = var.environment

  versioning_enabled = false

  lifecycle_rules = [
    {
      id              = "transition-to-ia"
      enabled         = true
      expiration_days = 365
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        }
      ]
    }
  ]
}