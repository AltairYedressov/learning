# S3 Bucket Module

This is a reusable module for creating S3 buckets with security best practices baked in. Every bucket created by this module gets encryption, public access blocking, and optional versioning, lifecycle rules, CORS configuration, and a custom bucket policy. It is called from `root/dev/s3/` to create the Velero backup bucket and the Thanos metrics bucket.

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      S3 Bucket Module                        │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                    S3 Bucket                            │  │
│  │                                                        │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │  │
│  │  │  Versioning   │  │  Encryption   │  │  Public     │  │  │
│  │  │  (optional)   │  │  AES256 or    │  │  Access     │  │  │
│  │  │              │  │  KMS          │  │  BLOCKED    │  │  │
│  │  └──────────────┘  └──────────────┘  └─────────────┘  │  │
│  │                                                        │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │  │
│  │  │  Lifecycle    │  │  CORS Rules   │  │  Bucket     │  │  │
│  │  │  Rules        │  │  (optional)   │  │  Policy     │  │  │
│  │  │  (optional)   │  │              │  │  (optional) │  │  │
│  │  └──────────────┘  └──────────────┘  └─────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘

Buckets created in root/dev/s3/:

┌───────────────────────────────┐  ┌────────────────────────────────┐
│ 372517046622-velero-backups-dev│  │ 372517046622-thanos-dev        │
│                               │  │                                │
│ Purpose: Kubernetes backups   │  │ Purpose: Long-term Prometheus  │
│ Versioning: ON                │  │          metrics storage       │
│ Lifecycle: Delete after 30d   │  │ Versioning: OFF                │
│                               │  │ Lifecycle:                     │
│ Accessed by: velero-role      │  │   30d -> STANDARD_IA           │
│ (via IRSA)                    │  │   365d -> Delete               │
│                               │  │                                │
└───────────────────────────────┘  │ Accessed by: thanos-role       │
                                   │ (via IRSA)                     │
                                   └────────────────────────────────┘
```

## File Descriptions

| File | Purpose |
|------|---------|
| `s3.tf` | The main resource file. Creates the S3 bucket, versioning configuration, server-side encryption (AES256 by default, KMS if a key is provided), public access block (all four settings enabled), optional lifecycle rules (with transitions and expiration), optional CORS rules, and an optional bucket policy. Uses `dynamic` blocks and `count` for optional features. |
| `variables.tf` | Declares all input variables with sensible defaults. |

## Resources Created

1. **`aws_s3_bucket.this`** - The bucket itself, tagged with name and environment.
2. **`aws_s3_bucket_versioning.this`** - Enables or suspends versioning based on the `versioning_enabled` variable.
3. **`aws_s3_bucket_server_side_encryption_configuration.this`** - Configures encryption. Uses AES256 (free, AWS-managed) by default, or KMS if you provide a `kms_key_id`.
4. **`aws_s3_bucket_public_access_block.this`** - Blocks ALL public access (ACLs and policies). This is a security best practice.
5. **`aws_s3_bucket_lifecycle_configuration.this`** (optional) - Only created if `lifecycle_rules` is non-empty. Supports transitions between storage classes (e.g., Standard to Standard-IA) and expiration (automatic deletion after N days).
6. **`aws_s3_bucket_cors_configuration.this`** (optional) - Only created if `cors_rules` is non-empty. Configures Cross-Origin Resource Sharing for web applications.
7. **`aws_s3_bucket_policy.this`** (optional) - Only created if `bucket_policy` is provided. Attaches a custom JSON policy to the bucket.

## Inputs

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `bucket_name` | `string` | Yes | - | Name of the S3 bucket. Must be globally unique across all AWS accounts. |
| `environment` | `string` | Yes | - | Environment name for tagging (e.g., `dev`, `prod`). |
| `versioning_enabled` | `bool` | No | `true` | Enable versioning. When ON, S3 keeps every version of every object -- useful for backups, bad for metrics data. |
| `kms_key_id` | `string` | No | `null` | KMS key ARN for encryption. If null, uses free AES256 encryption. |
| `lifecycle_rules` | `list(object)` | No | `[]` | List of lifecycle rules. Each rule has `id`, `enabled`, optional `expiration_days`, and a list of `transitions` (each with `days` and `storage_class`). |
| `cors_rules` | `list(object)` | No | `[]` | List of CORS rules. Each has `allowed_headers`, `allowed_methods`, `allowed_origins`, `expose_headers`, and `max_age_seconds`. |
| `bucket_policy` | `string` | No | `null` | A JSON string containing a custom bucket policy. |

## Outputs

This module currently has no outputs defined. If you need the bucket ARN or name downstream, you would add outputs.

## Dependency Chain

```
This module has no infrastructure dependencies.

It is called by root/dev/s3/ which creates:
    │
    ├── velero-backups bucket  ← accessed by velero-role (IRSA)
    └── thanos bucket          ← accessed by thanos-role (IRSA)

The IAM policies in iam-role-module/Policies/ reference these
bucket names, so the bucket names must match between modules.
```

## Usage Example

```hcl
module "velero_bucket" {
  source = "../../../s3"

  bucket_name        = "372517046622-velero-backups-dev"
  environment        = "dev"
  versioning_enabled = true

  lifecycle_rules = [
    {
      id              = "expire-old-backups"
      enabled         = true
      expiration_days = 30     # auto-delete backups older than 30 days
      transitions     = []
    }
  ]
}

module "thanos_bucket" {
  source = "../../../s3"

  bucket_name        = "372517046622-thanos-dev"
  environment        = "dev"
  versioning_enabled = false   # metrics data does not need versioning

  lifecycle_rules = [
    {
      id              = "transition-to-ia"
      enabled         = true
      expiration_days = 365    # delete after 1 year
      transitions = [
        {
          days          = 30
          storage_class = "STANDARD_IA"  # cheaper storage after 30 days
        }
      ]
    }
  ]
}
```

## Key Concepts for Beginners

- **S3 (Simple Storage Service)**: AWS's object storage. Think of it as a cloud hard drive where you store files (called "objects") in containers (called "buckets").
- **Versioning**: When enabled, S3 keeps every version of every file. If you overwrite a file, the old version is still there. Useful for backups, but costs more storage.
- **Server-Side Encryption (SSE)**: AWS encrypts data automatically when it is stored. AES256 is free and sufficient for most use cases. KMS gives you more control (key rotation, access auditing) but costs money per API call.
- **Public Access Block**: A safety net that prevents the bucket from ever being made public, even if someone adds a permissive bucket policy. All four settings should always be `true`.
- **Lifecycle Rules**: Automated policies that move objects between storage classes (e.g., Standard to Standard-IA for cost savings) or delete them after a certain number of days.
- **Storage Classes**: S3 offers different pricing tiers. `STANDARD` is the default (fast, expensive). `STANDARD_IA` (Infrequent Access) is cheaper for data you rarely read. Objects transition automatically via lifecycle rules.
- **CORS (Cross-Origin Resource Sharing)**: Allows web browsers to make requests to S3 from a different domain. Only needed if a web app directly accesses the bucket.
- **`dynamic` block**: A Terraform feature that generates repeated blocks of configuration from a list. Used here to create multiple lifecycle rules and CORS rules from the input variables.
