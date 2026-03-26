# ECR (Elastic Container Registry) Module

This Terraform module creates an AWS ECR repository for storing **Docker images** and **Helm charts** as OCI artifacts.

---

## How Much Does ECR Cost?

ECR is **practically free** for most use cases:

| What | Cost |
|---|---|
| **Creating repositories** | Free — you can create as many as you want |
| **Storage** | 500 MB/month free (first 12 months), then $0.10/GB/month |
| **Pull (same region)** | Free |
| **Pull (cross-region/internet)** | ~$0.09/GB |

Helm charts are tiny (a few KB each), so even dozens of chart versions cost almost nothing. Container images (100MB–1GB+) are what actually use storage.

## Do I Need One ECR Per Chart?

**Yes.** ECR works like Docker Hub — each repository holds **one artifact with multiple version tags**, not multiple different artifacts.

When you run:

```bash
helm push portfolio-0.1.0.tgz oci://123456.dkr.ecr.us-east-1.amazonaws.com/helm-charts
```

Helm appends the chart name from `Chart.yaml` automatically, so it pushes to:

```
123456.dkr.ecr.us-east-1.amazonaws.com/helm-charts/portfolio
                                       ^^^^^^^^^^^^^^^^^^^^
                                       This is the ECR repository name
```

So for multiple charts, you need multiple ECR repos:

```
helm-charts/portfolio       ← tags: 0.1.0, 0.2.0, 1.0.0
helm-charts/monitoring      ← tags: 0.1.0, 0.3.0
helm-charts/auth-service    ← tags: 1.0.0, 1.1.0
```

**But you don't pay per repository** — you only pay for the total storage across all of them. 50 repos with 10MB each costs the same as 1 repo with 500MB.

---

## Module Structure

```
terraform-infra/
├── ecr/                          # Reusable module (the template)
│   ├── main.tf                   # ECR resource definition
│   └── variables.tf              # Input variables
└── root/dev/ecr/                 # Dev environment (uses the module)
    ├── main.tf                   # Calls the module with dev-specific values
    ├── variables.tf              # Variable declarations
    ├── terraform.tfvars          # Actual values for dev
    └── providers.tf              # AWS provider config
```

### Why this structure?

The module (`ecr/`) is a **reusable template**. It defines *what* an ECR repo looks like but not *which* repo to create. The root config (`root/dev/ecr/`) calls the module and fills in the actual values. This way you can reuse the same module for dev, staging, and production by just changing the values.

---

## Module Inputs Explained

### `ecr_name` (required)

```hcl
variable "ecr_name" {
  type = string
}
```

The name of the ECR repository. This must match what your CI/CD pushes to. For example, if your GitHub Actions workflow pushes to `oci://<registry>/helm-charts/portfolio`, the ECR repo name must be `helm-charts/portfolio`.

### `environment` (required)

```hcl
variable "environment" {
  type = string
}
```

A tag applied to the repository (e.g., `dev`, `staging`, `prod`). This is for organization only — it doesn't change how the repo works.

### `image_tag_mutability` (default: `MUTABLE`)

```hcl
variable "image_tag_mutability" {
  type    = string
  default = "MUTABLE"
}
```

Controls whether you can overwrite an existing tag:
- **MUTABLE** (default) — you can push `v1.0.0` again and it overwrites the old one. Simpler for development
- **IMMUTABLE** — once `v1.0.0` is pushed, it's locked. Safer for production (prevents accidental overwrites)

### `scan_on_push` (default: `true`)

```hcl
variable "scan_on_push" {
  type    = bool
  default = true
}
```

When `true`, AWS automatically scans every image/chart you push for known security vulnerabilities (CVEs). The basic scanning is free. Keep this enabled.

---

## What the Module Creates

```hcl
resource "aws_ecr_repository" "default" {
  name                 = var.ecr_name              # repo name
  image_tag_mutability = var.image_tag_mutability   # MUTABLE or IMMUTABLE

  image_scanning_configuration {
    scan_on_push = var.scan_on_push                 # auto-scan for vulnerabilities
  }

  tags = {
    Environment = var.environment
    Name        = var.ecr_name
  }
}
```

This creates a single ECR repository. That's it — ECR repos are simple resources. The complexity is in how you organize and use them.

---

## Current Dev Configuration

```hcl
# terraform.tfvars
environment = "dev"
ecr_name    = "helm_charts"
```

This creates one ECR repository called `helm_charts`. To store multiple Helm charts, you will need to call this module multiple times (once per chart) or update the module to accept a list of names.
