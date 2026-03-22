# CI/CD Workflows

This document explains the two GitHub Actions workflows that automate infrastructure deployment and platform validation for the ProjectX EKS platform.

---

## Table of Contents

- [Overview](#overview)
- [Workflow 1: Terraform Multi-Stack Deploy](#workflow-1-terraform-multi-stack-deploy)
  - [What It Does](#what-it-does)
  - [When It Triggers](#when-it-triggers)
  - [Step-by-Step Flow](#step-by-step-flow)
  - [Multi-Stack Deployment Order](#multi-stack-deployment-order)
  - [Flux Bootstrap Integration](#flux-bootstrap-integration)
- [Workflow 2: Ephemeral Cluster Test](#workflow-2-ephemeral-cluster-test)
  - [What It Does](#what-it-does-1)
  - [When It Triggers](#when-it-triggers-1)
  - [Step-by-Step Flow](#step-by-step-flow-1)
  - [What Gets Validated](#what-gets-validated)
- [How GitHub OIDC Authentication Works](#how-github-oidc-authentication-works)
- [Environment Variables and Secrets](#environment-variables-and-secrets)
- [Setting Up the Workflows from Scratch](#setting-up-the-workflows-from-scratch)
- [Troubleshooting Common Failures](#troubleshooting-common-failures)

---

## Overview

```
                    +-------------------+
                    |   Git Push        |
                    +--------+----------+
                             |
              +--------------+--------------+
              |                             |
     feature/** or main            feature/PT**
              |                             |
              v                             v
  +------------------------+    +------------------------+
  | deploy-workflow.yaml   |    | validation-PT.yaml     |
  | Terraform Multi-Stack  |    | Ephemeral Cluster Test |
  +------------------------+    +------------------------+
  |                        |    |                        |
  | 1. Checkout            |    | 1. Checkout            |
  | 2. Setup Terraform     |    | 2. AWS OIDC Auth       |
  | 3. AWS OIDC Auth       |    | 3. Install Tools       |
  | 4. terraform init      |    | 4. Create EKS Cluster  |
  | 5. terraform fmt       |    | 5. Bootstrap Flux      |
  | 6. terraform validate  |    | 6. Wait 120s           |
  | 7. terraform plan      |    | 7. Run Validations     |
  | 8. terraform apply     |    | 8. Destroy Cluster     |
  |    (main branch only)  |    |    (always)            |
  +------------------------+    +------------------------+
```

There are two pipelines:

| Workflow | File | Purpose |
|----------|------|---------|
| Terraform Multi-Stack Deploy | `deploy-workflow.yaml` | Provisions AWS infrastructure (VPC, IAM, EKS, S3) via Terraform |
| Ephemeral Cluster Test | `validation-PT.yaml` | Spins up a throwaway EKS cluster, bootstraps Flux, validates everything works, then tears it down |

---

## Workflow 1: Terraform Multi-Stack Deploy

**File:** `.github/workflows/deploy-workflow.yaml`

### What It Does

This workflow manages the full AWS infrastructure lifecycle using Terraform. It provisions four independent "stacks" (networking, iam-roles, eks, s3) that together form the production-grade EKS platform. On feature branches it runs `plan` only (dry run). On `main` it runs `plan` followed by `apply` (real changes).

### When It Triggers

```yaml
on:
  push:
    branches:
      - feature/**    # Plan only (no apply)
      - main          # Plan + Apply
```

- **Any push to `feature/*` branches:** Runs init, format check, validate, and plan. No infrastructure changes are made. This lets you review what Terraform would do before merging.
- **Any push to `main`:** Runs the full pipeline including `terraform apply -auto-approve`. This is when actual AWS resources get created or modified.

### Step-by-Step Flow

The workflow uses a **matrix strategy** to run four parallel jobs, one per stack:

```yaml
strategy:
  matrix:
    stack: [networking, iam-roles, eks, s3]
```

Each matrix job executes these steps:

1. **Checkout Repository** -- Clones the repo so Terraform can access the `.tf` files.

2. **Setup Terraform** -- Installs Terraform v1.6.6 on the runner.

3. **Configure AWS Credentials (OIDC)** -- Authenticates to AWS using OpenID Connect (no stored access keys). The runner assumes the IAM role specified in `vars.IAM_ROLE`. See [How GitHub OIDC Authentication Works](#how-github-oidc-authentication-works) for details.

4. **Terraform Init** -- Initializes the Terraform working directory. The backend is configured dynamically:
   - Fetches the AWS account ID at runtime via `aws sts get-caller-identity`
   - State bucket: `<account-id>-terraform-state-dev`
   - State key: `dev/<stack>/terraform.tfstate`
   - Region: `us-east-1`
   - Encryption: enabled

5. **Terraform Format** -- Runs `terraform fmt -check` to ensure all `.tf` files follow standard formatting. Fails the pipeline if files are not formatted.

6. **Terraform Validate** -- Runs `terraform validate` to check syntax and internal consistency of the Terraform configuration.

7. **Terraform Plan** -- Generates an execution plan showing what resources will be created, modified, or destroyed. The `eks` stack receives GitHub-related variables (`TF_VAR_github_token`, `TF_VAR_github_org`, `TF_VAR_github_repo`) needed for Flux bootstrap.

8. **Terraform Apply** (main branch only) -- Applies the planned changes. This step is gated by `if: github.ref == 'refs/heads/main'` so feature branches never modify infrastructure.

### Multi-Stack Deployment Order

The four stacks are deployed in parallel via the matrix strategy. However, they have logical dependencies:

```
networking    (VPC, subnets, security groups, IGW, route tables)
    |
    +---> iam-roles   (EKS cluster role, worker node role, IRSA roles)
    |         |
    |         v
    +---> eks         (EKS cluster, ASG, launch template, addons, Flux bootstrap)
    |
    +---> s3          (Velero backup bucket, Thanos metrics bucket)
```

Each stack's Terraform configuration lives under:
```
terraform-infra/root/dev/<stack>/
    main.tf           # Module calls
    variables.tf      # Variable declarations
    terraform.tfvars  # Variable values
    providers.tf      # AWS provider config
    backend.tf        # S3 backend config
```

These root modules reference shared modules:
- `terraform-infra/networking/` -- VPC, subnets, IGW, route tables, security groups
- `terraform-infra/iam-role-module/` -- Reusable IAM role with custom/managed policies
- `terraform-infra/eks-cluster/` -- EKS cluster, ASG, launch template, OIDC, Flux bootstrap
- `terraform-infra/s3/` -- S3 bucket with versioning, encryption, lifecycle rules

### Flux Bootstrap Integration

The `eks` stack includes Flux bootstrap as a Terraform resource (`flux_bootstrap_git` in `terraform-infra/eks-cluster/flux.tf`). When Terraform creates the EKS cluster:

1. The Flux provider connects to the new cluster using the EKS endpoint and CA certificate.
2. The GitHub provider authenticates using the `FLUX_GITHUB_PAT` secret.
3. The `flux_bootstrap_git` resource installs Flux components into the cluster and creates the `clusters/dev-projectx/flux-system/` directory in the Git repository.
4. Flux then watches the `clusters/dev-projectx/` path and reconciles all Kustomization resources (monitoring, sealed-secrets, karpenter, velero, thanos).

---

## Workflow 2: Ephemeral Cluster Test

**File:** `.github/workflows/validation-PT.yaml`

### What It Does

This workflow creates a temporary EKS cluster using `eksctl`, bootstraps Flux onto it, waits for all deployments to converge, runs a comprehensive validation suite, and then destroys the cluster. It is a full integration test that proves your GitOps configuration actually works on a real cluster.

### When It Triggers

```yaml
on:
  push:
    branches:
      - feature/PT**   # Only branches starting with "feature/PT"
```

This means you push to a branch like `feature/PT-test-monitoring` or `feature/PT-validate-karpenter` to trigger the test pipeline.

### Step-by-Step Flow

```
 1. Checkout code
 2. Authenticate to AWS via OIDC
 3. Install tools (eksctl, kubectl, flux CLI)
 4. Create temporary EKS cluster (eksctl)
 5. Bootstrap Flux pointing at clusters/test/ path
 6. Wait 120 seconds for reconciliation
 7. Run validation checks
 8. Destroy cluster (always, even if tests fail)
```

**Step 3 -- Install Tools** (`scripts/tools-installation.sh`):
- Downloads and installs `eksctl` (latest release)
- Downloads and installs `kubectl` v1.34.0
- Downloads and installs the Flux CLI via the official install script

**Step 4 -- Create Temporary Cluster** (`scripts/cluster-creation.sh`):
- Creates an EKS cluster named `pr-<github-run-id>` (unique per workflow run)
- Uses `t3.medium` instances with 2 nodes (min 1, max 3)
- Cluster is created in `us-east-1`

**Step 5 -- Bootstrap Flux** (`scripts/bootstrap-flux.sh`):
- Runs `flux bootstrap github` pointing at the current branch
- Uses the `clusters/test/` path in the repo
- Waits for Flux pods to become ready
- Triggers initial reconciliation of sources and kustomizations

**Step 6 -- Wait** :
- Sleeps 120 seconds to allow Helm releases to be fetched, rendered, and applied

**Step 7 -- Run Validation** (`scripts/validation.sh`):
- Checks all nodes are `Ready`
- Checks for any failed pods across all namespaces
- Verifies Flux controllers are healthy and all kustomizations show `True` status
- Verifies Prometheus stack (Grafana deployment, Prometheus StatefulSet)
- Verifies Karpenter deployment and NodePool readiness (if installed)
- Verifies EBS CSI driver is healthy

**Step 8 -- Destroy Cluster** (`scripts/destroy-cluster.sh`):
- Runs with `if: always()` so the cluster is cleaned up even if tests fail
- Deletes the EKS cluster via `eksctl delete cluster`

### What Gets Validated

| Check | What It Verifies |
|-------|-----------------|
| Node readiness | All worker nodes are in `Ready` state |
| Pod health | No pods in failed state across all namespaces |
| Flux controllers | All Flux deployments in `flux-system` are rolled out |
| Flux kustomizations | All Flux kustomizations show `True` (reconciled) |
| Monitoring | Grafana deployment and Prometheus StatefulSet are running |
| Karpenter | Karpenter deployment is running, NodePool is `Ready` |
| EBS CSI | EBS CSI controller deployment is running |

---

## How GitHub OIDC Authentication Works

Both workflows use GitHub OIDC (OpenID Connect) to authenticate with AWS. This means **no AWS access keys are stored as GitHub secrets**. Here is how it works:

```
GitHub Actions Runner                          AWS
       |                                        |
       |  1. Request OIDC token from GitHub     |
       |     (contains repo, branch, workflow)  |
       |                                        |
       |  2. Present OIDC token to AWS STS      |
       |--------------------------------------->|
       |                                        |
       |  3. AWS validates token against         |
       |     the GitHub OIDC provider            |
       |     (configured as IAM identity provider)|
       |                                        |
       |  4. AWS checks IAM role trust policy:   |
       |     - Is the token issuer GitHub?       |
       |     - Does repo/branch match?           |
       |                                        |
       |  5. AWS returns temporary credentials   |
       |<---------------------------------------|
       |                                        |
       |  6. Runner uses temp creds for          |
       |     Terraform / eksctl / AWS CLI        |
```

**Why this is better than access keys:**
- No long-lived credentials to rotate or leak
- Credentials are scoped to a single workflow run (typically 1 hour TTL)
- The IAM role trust policy can restrict which repos, branches, and workflows can assume it
- If the repository is compromised, the attacker cannot extract permanent credentials

**AWS-side setup required:**
1. An IAM OIDC Identity Provider pointing to `https://token.actions.githubusercontent.com`
2. An IAM role (`GithubActionsTerraformDeploy`) with a trust policy that allows `sts:AssumeRoleWithWebIdentity` from the GitHub OIDC provider, scoped to your repo
3. The role ARN is stored as a GitHub Actions **variable** (not secret): `vars.IAM_ROLE`

---

## Environment Variables and Secrets

### GitHub Actions Variables (Settings > Secrets and variables > Actions > Variables)

| Variable | Description | Example |
|----------|-------------|---------|
| `IAM_ROLE` | ARN of the IAM role to assume via OIDC | `arn:aws:iam::372517046622:role/GithubActionsTerraformDeploy` |

### GitHub Actions Secrets (Settings > Secrets and variables > Actions > Secrets)

| Secret | Description | Used By |
|--------|-------------|---------|
| `FLUX_GITHUB_PAT` | GitHub Personal Access Token with `repo` scope. Used by Flux to read/write the Git repository and by Terraform to bootstrap Flux. | Both workflows |

### Workflow Environment Variables

These are set in the workflow files and do not need manual configuration:

| Variable | Value | Description |
|----------|-------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region for all operations |
| `ENVIRONMENT_STAGE` | `dev` | Determines which Terraform root module to use (`root/dev/`) |
| `CLUSTER_NAME` | `pr-<run-id>` | (Validation only) Unique name for the ephemeral cluster |

---

## Setting Up the Workflows from Scratch

### Prerequisites

1. **AWS Account** with permissions to create IAM roles, EKS clusters, VPCs, and S3 buckets.
2. **GitHub repository** with Actions enabled.

### Step 1: Create the Terraform State Bucket

Run the bootstrap configuration locally:

```bash
cd terraform-infra/bootstrap
terraform init
terraform apply -var-file="bootstrap.tfvars"
```

This creates:
- S3 bucket: `<account-id>-terraform-state-dev`
- DynamoDB table: `<account-id>-terraform-lock-dev` (for state locking)

### Step 2: Configure GitHub OIDC in AWS

1. In the AWS Console, go to IAM > Identity providers > Add provider
2. Choose OpenID Connect
3. Provider URL: `https://token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`

### Step 3: Create the GitHub Actions IAM Role

Create an IAM role named `GithubActionsTerraformDeploy` with:

**Trust policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<GITHUB_ORG>/<REPO_NAME>:*"
        }
      }
    }
  ]
}
```

**Permissions:** Attach policies that allow managing VPC, EKS, IAM, S3, EC2, and DynamoDB resources. For initial setup, `AdministratorAccess` works but should be scoped down for production.

### Step 4: Configure GitHub Repository Settings

1. Go to Settings > Secrets and variables > Actions
2. Under **Variables**, add:
   - `IAM_ROLE`: The ARN of the role created in Step 3
3. Under **Secrets**, add:
   - `FLUX_GITHUB_PAT`: A GitHub PAT with `repo` scope (needed for Flux to push to the repository)

### Step 5: Create a GitHub PAT for Flux

1. Go to GitHub > Settings > Developer settings > Personal access tokens > Tokens (classic)
2. Create a new token with `repo` scope (full control of private repositories)
3. Add it as the `FLUX_GITHUB_PAT` secret in your repository

### Step 6: Push and Trigger

```bash
# For infrastructure deployment (plan only):
git checkout -b feature/my-changes
git push origin feature/my-changes

# For infrastructure deployment (plan + apply):
git checkout main
git merge feature/my-changes
git push origin main

# For ephemeral cluster testing:
git checkout -b feature/PT-test
git push origin feature/PT-test
```

---

## Troubleshooting Common Failures

### OIDC Authentication Fails

**Error:** `Not authorized to perform sts:AssumeRoleWithWebIdentity`

**Causes:**
- The IAM OIDC provider is not configured in the AWS account
- The IAM role trust policy does not match the repository name or branch pattern
- The `vars.IAM_ROLE` variable contains the wrong role ARN
- The OIDC provider thumbprint is outdated

**Fix:**
- Verify the OIDC provider exists in IAM > Identity providers
- Check the role trust policy `Condition` block matches your `repo:org/name:*` pattern
- Ensure `id-token: write` permission is set in the workflow

### Terraform Init Fails

**Error:** `Error configuring S3 Backend`

**Causes:**
- The state bucket does not exist (run bootstrap first)
- The IAM role does not have `s3:GetObject` / `s3:PutObject` on the state bucket
- The DynamoDB lock table does not exist

**Fix:**
- Run the bootstrap Terraform configuration to create the bucket and lock table
- Ensure the IAM role has S3 and DynamoDB permissions

### Terraform Plan Fails on EKS Stack

**Error:** `variable "github_token" is required`

**Causes:**
- The `FLUX_GITHUB_PAT` secret is not set in the repository

**Fix:**
- Add the `FLUX_GITHUB_PAT` secret under Settings > Secrets and variables > Actions > Secrets

### Ephemeral Cluster Creation Times Out

**Error:** `waiting for CloudFormation stack` or eksctl times out

**Causes:**
- The IAM role does not have permissions to create EKS clusters and EC2 instances
- AWS service limits reached (VPC, EIP, or EC2 quotas)
- Region capacity issues

**Fix:**
- Check AWS Service Quotas for the `us-east-1` region
- Ensure the IAM role has EKS and EC2 permissions
- Check CloudFormation events in the AWS Console for the specific error

### Flux Bootstrap Fails

**Error:** `flux bootstrap github` returns authentication error

**Causes:**
- The `FLUX_GITHUB_PAT` secret is invalid or expired
- The PAT does not have `repo` scope
- The repository name or org does not match

**Fix:**
- Regenerate the PAT with `repo` scope
- Verify `GITHUB_ORG` and `GITHUB_REPO` environment variables are correct

### Validation Fails on Monitoring

**Error:** `deployment kube-prometheus-stack-grafana not found`

**Causes:**
- The Helm release has not finished installing (120-second wait may not be enough)
- The HelmRepository source is unreachable
- The HelmRelease has a configuration error

**Fix:**
- Check Flux kustomization status: `flux get kustomizations`
- Check HelmRelease status: `flux get helmreleases -A`
- Check events: `kubectl get events -n monitoring --sort-by='.lastTimestamp'`

### Cluster Destroy Fails

**Error:** `eksctl delete cluster` fails or times out

**Causes:**
- Resources created by Kubernetes (load balancers, EBS volumes) are blocking deletion
- CloudFormation stack is in `DELETE_FAILED` state

**Fix:**
- Manually check for orphaned load balancers or ENIs in the AWS Console
- Delete the CloudFormation stacks manually if needed
- Check for finalizers on Kubernetes resources that prevent cleanup

### Concurrency Issues

The deploy workflow uses concurrency groups to prevent parallel runs on the same branch:

```yaml
concurrency:
  group: terraform-${{ github.ref }}
  cancel-in-progress: false
```

If a workflow appears stuck, check if a previous run is still in progress. The `cancel-in-progress: false` setting means new pushes will queue, not cancel the running job.
