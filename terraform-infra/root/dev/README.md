# Root Dev Workspace

This is the top-level directory where all the reusable Terraform modules are wired together with actual values for the **dev** environment. Each subdirectory here is a separate Terraform workspace with its own state file, provider configuration, and backend. You run `terraform apply` in each subdirectory (in the correct order) to build the complete dev environment.

This separation into multiple workspaces is intentional -- it limits the "blast radius" of each apply. If the EKS module has an error, it does not affect the networking state.

## Architecture - Full Stack Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                      root/dev/ - Dev Environment                     │
│                      AWS Account: 372517046622                       │
│                      Region: us-east-1                               │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                    1. networking/                               │  │
│  │                                                                │  │
│  │  VPC + Subnets + IGW + Route Tables + Security Groups          │  │
│  │  (cluster-sg, worker-nodes-sg, database-sg)                    │  │
│  │  + Inter-SG rules (worker->cluster, control plane->kubelet)    │  │
│  └─────────────────────────────┬──────────────────────────────────┘  │
│                                │                                     │
│  ┌─────────────────────────────┼──────────────────────────────────┐  │
│  │                    2. iam-roles/                                │  │
│  │                                                                │  │
│  │  eks-cluster-role  |  eks_worker_nodes_role  |  ebs-csi-irsa   │  │
│  │  karpenter-irsa    |  velero-role            |  thanos-role     │  │
│  │  (IRSA roles use OIDC provider from EKS)                      │  │
│  └─────────────────────────────┬──────────────────────────────────┘  │
│                                │                                     │
│  ┌─────────────────────────────┼──────────────────────────────────┐  │
│  │                    3. s3/                                      │  │
│  │                                                                │  │
│  │  372517046622-velero-backups-dev  (Kubernetes backups, 30d TTL)│  │
│  │  372517046622-thanos-dev          (Prometheus metrics, 365d)   │  │
│  └─────────────────────────────┬──────────────────────────────────┘  │
│                                │                                     │
│  ┌─────────────────────────────┼──────────────────────────────────┐  │
│  │                    4. eks/                                     │  │
│  │                                                                │  │
│  │  EKS Cluster "projectx" (K8s 1.34)                            │  │
│  │  + Add-ons (vpc-cni, ebs-csi, coredns, kube-proxy)            │  │
│  │  + Self-managed nodes (ASG, 80% Spot)                         │  │
│  │  + Flux CD (GitOps from GitHub)                               │  │
│  │  + Access entries (altoha user, GitHub Actions role)           │  │
│  └─────────────────────────────┬──────────────────────────────────┘  │
│                                │                                     │
│  ┌─────────────────────────────┼──────────────────────────────────┐  │
│  │                    5. database/                                │  │
│  │                                                                │  │
│  │  RDS MySQL 8.0 (db.t3.micro)                                  │  │
│  │  Private subnets, database-sg, IAM auth                       │  │
│  │  Password in Secrets Manager, 14-day backups                  │  │
│  │  DR: OFF in dev (available for prod)                          │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

## Subdirectory Descriptions

### 1. `networking/` - VPC and Network Infrastructure

Calls the five networking sub-modules (vpc-module, subnets, igw, route-tables, security-group) and creates additional inter-security-group rules specific to this environment.

| File | Purpose |
|------|---------|
| `main.tf` | Calls all networking sub-modules and creates additional security group rules: workers-to-cluster (port 443), control-plane-to-kubelet (port 10250), worker-to-worker (all ports), and VPC-to-kubelet. Also creates three security groups: `cluster-sg` (port 443), `worker-nodes-sg`, and `database-sg` (port 3306). |
| `variables.tf` | Declares `vpc_cidr`, `project_name`, `environment`, `subnets` map, and `protocol`. |
| `backend.tf` | Configures the S3 backend (`372517046622-terraform-state-dev` bucket) with DynamoDB locking. |
| `providers.tf` | Empty file (providers inherited or set elsewhere). |

**Key Variables:**

| Variable | Type | Description |
|----------|------|-------------|
| `vpc_cidr` | `string` | VPC IP range (e.g., `10.0.0.0/16`). |
| `project_name` | `string` | Project name for tags. |
| `environment` | `string` | Environment name (e.g., `dev`). |
| `subnets` | `map(object)` | Map defining all subnets with CIDR, AZ, and public/private flag. |

---

### 2. `iam-roles/` - IAM Roles for EKS and Services

Creates all IAM roles needed by the EKS cluster and its in-cluster services using the iam-role-module.

| File | Purpose |
|------|---------|
| `main.tf` | Calls the iam-role-module six times to create: `eks-cluster-role` (for EKS service), `eks_worker_nodes_role` (for EC2 worker nodes), `ebs-csi-irsa-role` (IRSA for EBS CSI driver), `karpenter_irsa_role` (IRSA for Karpenter autoscaler), `velero-role` (IRSA for Velero backup), and `thanos-role` (IRSA for Thanos metrics). |
| `variables.tf` | Declares role names, policy ARN lists, and environment. Contains defaults for all AWS managed policy ARNs. |
| `data-blocks.tf` | Looks up the existing EKS OIDC provider by URL. This is needed for IRSA roles to reference the OIDC provider ARN in their trust policies. |
| `backend.tf` | Configures the S3 backend with DynamoDB locking. |
| `providers.tf` | Configures the AWS provider (v6.0+). |

**Key Variables:**

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `environment` | `string` | - | Environment name. |
| `eks_cluster_role` | `string` | `"eks-cluster-role"` | Name of the EKS cluster role. |
| `cluster_policy` | `list(string)` | `[EKSClusterPolicy, EKSServicePolicy]` | Managed policies for the cluster role. |
| `eks_worker_nodes_role` | `string` | `"eks_worker_nodes_role"` | Name of the worker nodes role. |
| `eks_worker_nodes_policy` | `list(string)` | `[ECR, CNI, EC2, ELB policies]` | Managed policies for worker nodes. |
| `ebs_csi_irsa_role` | `string` | `"ebs-csi-irsa-role"` | Name of the EBS CSI IRSA role. |
| `karpenter_irsa_role` | `string` | `"karpenter_irsa_role"` | Name of the Karpenter IRSA role. |

---

### 3. `s3/` - Application S3 Buckets

Creates S3 buckets for Velero (Kubernetes backups) and Thanos (long-term Prometheus metrics storage).

| File | Purpose |
|------|---------|
| `main.tf` | Calls the s3 module twice: once for the Velero backup bucket (versioning on, 30-day expiration) and once for the Thanos bucket (versioning off, 30-day transition to Standard-IA, 365-day expiration). |
| `variables.tf` | Declares `environment`. |
| `backend.tf` | Configures the S3 backend with DynamoDB locking. |
| `providers.tf` | Configures the AWS provider (v6.0+). |

**Buckets Created:**

| Bucket Name | Purpose | Versioning | Lifecycle |
|-------------|---------|------------|-----------|
| `372517046622-velero-backups-dev` | Kubernetes cluster backups via Velero | ON | Delete after 30 days |
| `372517046622-thanos-dev` | Long-term Prometheus metrics via Thanos | OFF | Move to Standard-IA at 30 days, delete at 365 days |

---

### 4. `eks/` - EKS Kubernetes Cluster

Creates the EKS cluster with all components: control plane, worker nodes, add-ons, Flux CD, and access control.

| File | Purpose |
|------|---------|
| `main.tf` | Calls the eks-cluster module with dev-specific values. Sets the Flux path to `clusters/dev-projectx`. |
| `variables.tf` | Declares `cluster_name`, `k8s_version` (default `1.34`), `environment`, `project_name`, `vpc_cidr`, and GitHub settings for Flux (org, repo, token). |
| `backend.tf` | Configures the S3 backend with DynamoDB locking. |
| `providers.tf` | Configures AWS (v6.0+), Flux (v1.8+), Kubernetes (v2.38+), and GitHub (v6.11+) providers. |

**Key Variables:**

| Variable | Type | Description |
|----------|------|-------------|
| `cluster_name` | `string` | EKS cluster name (e.g., `projectx`). |
| `k8s_version` | `string` | Kubernetes version (default: `1.34`). |
| `github_org` | `string` | GitHub org/username for Flux (passed from CI/CD). |
| `github_repo` | `string` | GitHub repo for Flux (passed from CI/CD). |
| `github_token` | `string` | GitHub token for Flux (sensitive, passed from CI/CD). |

---

### 5. `database/` - RDS MySQL Database

Creates the MySQL database in private subnets with production-ready security settings.

| File | Purpose |
|------|---------|
| `main.tf` | Calls the database module with dev-specific values: MySQL 8.0, db.t3.micro, IAM auth, 14-day backups, deletion protection ON, DR OFF. Includes comments explaining the three DR tiers. |
| `variables.tf` | Declares `vpc_cidr`, `db_name`, `db_username`, and `environment`. |
| `data-blocks.tf` | Looks up the VPC, private subnets, and database-sg security group. |
| `backend.tf` | Configures the S3 backend with DynamoDB locking. |
| `providers.tf` | Configures two AWS providers: the primary (`us-east-1`) and a DR alias (`us-west-2`) needed for cross-region DR features. |

**Key Variables:**

| Variable | Type | Description |
|----------|------|-------------|
| `vpc_cidr` | `string` | VPC CIDR to look up the VPC. |
| `db_name` | `string` | Database name. |
| `db_username` | `string` | Master username. |
| `environment` | `string` | Environment name. |

## Shared Backend Configuration

All five subdirectories use the same S3 backend for state storage:

```hcl
backend "s3" {
  bucket         = "372517046622-terraform-state-dev"
  key            = "<unique-path>/terraform.tfstate"    # different per subdirectory
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "372517046622-terraform-lock-dev"
}
```

This backend was created by the `bootstrap/` module.

## Deployment Order

You must apply these workspaces in a specific order because they depend on each other:

```
Step 1: networking/
    Creates: VPC, subnets, IGW, route tables, security groups
    No dependencies on other dev workspaces.

Step 2: iam-roles/
    Creates: All IAM roles (cluster, workers, IRSA roles)
    Depends on: The EKS OIDC provider URL (hardcoded in data-blocks.tf)
    Note: IRSA roles need the OIDC provider to exist, which is created by EKS.
          For initial setup, create cluster + worker roles first, then EKS, then IRSA roles.

Step 3: s3/
    Creates: Velero and Thanos S3 buckets
    No strict dependencies, but bucket names must match IAM policy references.

Step 4: eks/
    Creates: EKS cluster, nodes, add-ons, Flux
    Depends on: networking (VPC, subnets, SGs) + iam-roles (cluster, worker, EBS CSI roles)

Step 5: database/
    Creates: RDS MySQL instance
    Depends on: networking (VPC, private subnets, database-sg)
```

```
                   bootstrap
                      │
                      v
               ┌──────────────┐
               │  networking   │
               └──────┬───────┘
                      │
          ┌───────────┼───────────┐
          v           v           v
    ┌──────────┐ ┌─────────┐ ┌────────┐
    │ iam-roles│ │   s3     │ │database│
    └────┬─────┘ └─────────┘ └────────┘
         │
         v
    ┌──────────┐
    │   eks    │
    └──────────┘
```

## CI/CD Integration

This project uses **GitHub OIDC** for CI/CD authentication -- no long-lived AWS credentials are stored in GitHub. The `GithubActionsTerraformDeploy` role (created in iam-roles) is assumed by GitHub Actions workflows using OIDC federation. This role has EKS ClusterAdmin access for deploying via Terraform.

Sensitive values like `github_token` are passed as variables from CI/CD, never hardcoded in the Terraform files.

## Key Concepts for Beginners

- **Root Module vs Reusable Module**: The directories under `root/dev/` are "root modules" -- they call reusable modules (in `networking/`, `eks-cluster/`, etc.) and provide concrete values. Think of reusable modules as functions and root modules as the `main()` that calls them.
- **Workspace Separation**: Each subdirectory has its own Terraform state. This means `terraform apply` in `eks/` only affects EKS resources. If something goes wrong, it does not corrupt the networking or database state.
- **Backend Configuration**: The `backend.tf` in each directory tells Terraform where to store its state file. All directories use the same S3 bucket but different keys (paths within the bucket).
- **Data Sources**: The `data-blocks.tf` files look up resources created by other workspaces. For example, the database workspace uses `data "aws_vpc"` to find the VPC created by the networking workspace. This is how separate workspaces share information without being in the same state.
- **Provider Aliases**: The database workspace defines `provider "aws" { alias = "dr" }` pointing to us-west-2. This lets the module create resources in a different region (for DR) from the same Terraform configuration.
