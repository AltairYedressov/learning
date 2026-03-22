# Bootstrap - Terraform State Management

This module creates the foundational infrastructure that Terraform itself needs to operate: a remote state backend. Before you can run any other Terraform module in this project, you must run this one first. It creates an S3 bucket to store Terraform's state files (the record of what infrastructure exists) and a DynamoDB table to prevent two people from making changes at the same time (state locking).

> **Why is this important?** By default, Terraform stores its state locally in a file on your computer. That is fine for learning, but in a team environment you need a shared, remote location. S3 + DynamoDB is the standard AWS pattern for this.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   AWS Account (372517046622)             │
│                   Region: us-east-1                      │
│                                                         │
│  ┌──────────────────────┐   ┌────────────────────────┐  │
│  │   S3 Bucket          │   │   DynamoDB Table        │  │
│  │                      │   │                         │  │
│  │  Stores .tfstate     │   │  Prevents concurrent    │  │
│  │  files for ALL other │   │  writes (state locking) │  │
│  │  modules             │   │                         │  │
│  │                      │   │  Hash Key: "LockID"     │  │
│  │  - Versioning: ON    │   │  Billing: Pay-per-req   │  │
│  │  - Encryption: AES256│   │                         │  │
│  │  - Public Access: OFF│   └────────────────────────┘  │
│  └──────────────────────┘                               │
│           │                           │                  │
│           └──────────┬────────────────┘                  │
│                      │                                   │
│          Used by every other module                      │
│          (networking, eks, iam-roles, database, s3)      │
└─────────────────────────────────────────────────────────┘
```

## File Descriptions

| File | Purpose |
|------|---------|
| `main.tf` | Defines all the resources: the S3 bucket (with versioning, encryption, and public access block) and the DynamoDB table for state locking. |
| `providers.tf` | Configures the AWS provider to use the `us-east-1` region. |
| `variables.tf` | Declares the single input variable: `ACCOUNT_ID`. |

## Resources Created

1. **`aws_s3_bucket.terraform_state`** - The S3 bucket named `{ACCOUNT_ID}-terraform-state-dev`. This is where all `.tfstate` files are stored.
2. **`aws_s3_bucket_versioning.versioning`** - Enables versioning on the bucket so you can recover previous state files if something goes wrong.
3. **`aws_s3_bucket_server_side_encryption_configuration.encryption`** - Encrypts all objects in the bucket using AES256 (AWS-managed encryption).
4. **`aws_s3_bucket_public_access_block.block_public`** - Blocks all public access to the bucket. State files contain sensitive information and must never be public.
5. **`aws_dynamodb_table.terraform_locks`** - A DynamoDB table named `{ACCOUNT_ID}-terraform-lock-dev` that Terraform uses to acquire a lock before making changes. This prevents two `terraform apply` runs from corrupting state.

## Inputs

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `ACCOUNT_ID` | `string` | Yes | - | The AWS account ID. Used to create globally unique bucket and table names. |

## Outputs

This module has no outputs. Other modules reference the bucket and table names directly in their `backend "s3"` configuration blocks.

## Dependency Chain

```
bootstrap (this module)     <-- MUST be applied first, manually
    │
    ├── networking          <-- uses the S3 backend created here
    ├── iam-roles           <-- uses the S3 backend created here
    ├── eks                 <-- uses the S3 backend created here
    ├── database            <-- uses the S3 backend created here
    └── s3                  <-- uses the S3 backend created here
```

## Usage Example

```bash
# This is the ONLY module you run with local state (no backend yet)
cd terraform-infra/bootstrap

# Initialize Terraform (uses local state since backend doesn't exist yet)
terraform init

# Apply to create the S3 bucket and DynamoDB table
terraform apply -var="ACCOUNT_ID=372517046622"
```

> **Important:** This module uses local state (no `backend "s3"` block) because the S3 bucket it creates does not exist yet. After this runs, all other modules can use the remote backend.

## Key Concepts for Beginners

- **Terraform State**: A JSON file that maps your `.tf` code to real AWS resources. Terraform reads this to know what already exists.
- **State Locking**: A mechanism using DynamoDB to prevent two people from running `terraform apply` at the same time, which would corrupt the state file.
- **Server-Side Encryption (SSE)**: AWS automatically encrypts data when it is written to S3 and decrypts it when read. You never see the encryption happen.
- **Versioning**: S3 keeps every version of every file. If a state file gets corrupted, you can roll back to a previous version.
