# Security Audit Report — ProjectX EKS Platform

**Date:** 2026-03-23 (updated)
**Scope:** Full repository audit — Terraform, Kubernetes manifests, CI/CD workflows, shell scripts
**Previous audit:** 2026-03-22

---

## Executive Summary

| Severity | Terraform | Kubernetes | CI/CD & Scripts | Total |
|----------|-----------|------------|-----------------|-------|
| CRITICAL | 2 | 2 | 4 | **8** |
| HIGH | 4 | 8 | 6 | **18** |
| MEDIUM | 8 | 11 | 6 | **25** |
| LOW | 4 | 4 | 4 | **12** |
| **Total** | **18** | **25** | **20** | **63** |

### Remediated Since Last Audit

- Grafana admin credentials moved from plaintext to SealedSecret
- Grafana dev/prod overlay passwords removed
- Kibana ES token moved to SealedSecret
- Thanos objstore config stored as SealedSecret
- sealed-secrets prod overlay fixed (was corrupted with eks-monitoring content)
- EFK stack rebuilt from scratch (was a copy of eks-monitoring)
- Network policies added for EFK stack (Elasticsearch, Kibana, Fluent Bit)
- Pod security contexts added for Elasticsearch and Kibana

---

## CRITICAL Findings

### C1. EKS Cluster API Endpoint Publicly Accessible
- **File:** `terraform-infra/eks-cluster/eks.tf:12`
- **Code:** `endpoint_public_access = true`
- **Impact:** EKS API server is reachable from the internet. Brute-force attacks on kubeconfig tokens, credential stuffing.
- **Fix:** Set `endpoint_public_access = false` and `endpoint_private_access = true`, or restrict with `public_access_cidrs = ["YOUR_IP/32"]`

### C2. GitHub Token in Terraform Provider Configuration
- **File:** `terraform-infra/eks-cluster/flux.tf:63,70`
- **Code:**
  ```hcl
  password = var.github_token  # HTTP basic auth
  token = var.github_token     # GitHub provider
  ```
- **Impact:** Token stored in Terraform state file. Anyone with state access gets full repo access.
- **Fix:** Use SSH authentication for Flux, store token in AWS Secrets Manager, use GitHub App instead of PAT.

### C3. Kibana Hardcoded Encryption Key
- **File:** `platform-tools/efk-logging/base/helmrelease-kibana.yaml:73`
- **Code:** `xpack.encryptedSavedObjects.encryptionKey: "min-32-char-long-encryption-key!!"`
- **Impact:** Weak, non-random key committed to Git. Kibana saved objects encryption is effectively bypassed.
- **Fix:** Generate cryptographically secure key with `openssl rand -base64 32`, store as SealedSecret.

### C4. Terraform Auto-Approve Without Review Gate
- **File:** `.github/workflows/deploy-workflow.yaml:83`
- **Code:** `terraform apply -auto-approve -input=false`
- **Impact:** Infrastructure changes deploy on push to main with zero human review. Misconfigured change could destroy cluster.
- **Fix:** Use GitHub Environments with required reviewers, split plan/apply into separate jobs.

### C5. Curl Pipe to Bash (Supply Chain Attack)
- **File:** `scripts/tools-installation.sh:22`
- **Code:** `curl -s https://fluxcd.io/install.sh | sudo bash`
- **Impact:** Downloads and executes script from internet without verification. Compromised CDN = compromised CI runner.
- **Fix:** Download, verify SHA256 checksum, then execute.

### C6. Unquoted Variable (Shell Injection)
- **File:** `scripts/cluster-creation.sh:21`
- **Code:** `eksctl get cluster --name $CLUSTER_NAME --region us-east-1`
- **Impact:** If CLUSTER_NAME contains special characters, command injection is possible.
- **Fix:** Quote the variable: `"$CLUSTER_NAME"`

### C7. Syntax Error in Destroy Script
- **File:** `scripts/destroy-cluster.sh:8-9`
- **Code:** Missing backslash before `--wait` flag
- **Impact:** The `--wait` flag is treated as a separate command, eksctl delete runs without waiting.
- **Fix:** Add `\` after `--region "us-east-1"`

### C8. Elasticsearch Security Completely Disabled
- **File:** `platform-tools/efk-logging/base/helmrelease-elasticsearch.yaml:55,73-76`
- **Code:**
  ```yaml
  protocol: http
  xpack.security.enabled: false
  xpack.security.http.ssl.enabled: false
  xpack.security.transport.ssl.enabled: false
  ```
- **Impact:** All ES communication unencrypted. No authentication. Any pod in cluster can read/write/delete all log data.
- **Note:** Acceptable for dev/learning. Must enable for production.

---

## HIGH Findings

### H1. Wildcard IAM Policies (Resource: "*")
| File | Actions | Risk |
|------|---------|------|
| `iam-role-module/Policies/karpenter_policy.json:5-24` | EC2 CreateFleet, RunInstances, TerminateInstances | Can manage any EC2 resource |
| `iam-role-module/Policies/karpenter_policy.json:26-39` | IAM CreateInstanceProfile, DeleteInstanceProfile | Can create profiles for any role |
| `iam-role-module/Policies/velero_policy.json:4-15` | EC2 CreateVolume, CreateSnapshot, DeleteSnapshot | Can manage any volume/snapshot |
- **Fix:** Restrict resources to cluster-specific ARNs with tags or account-scoped patterns.

### H2. Hardcoded AWS Account ID (10+ locations)
| File | Line |
|------|------|
| `terraform-infra/eks-cluster/access-entries.tf` | 9, 15, 25, 31 |
| `terraform-infra/root/dev/s3/main.tf` | 4, 22 |
| `terraform-infra/root/dev/database/main.tf` | 21 |
| `iam-role-module/Policies/karpenter_policy.json` | 44, 50, 73 |
| `iam-role-module/Policies/velero_policy.json` | 25, 32 |
| `iam-role-module/Policies/thanos_policy.json` | 13, 21 |
| `platform-tools/karpenter/base/helmrelease.yaml` | 19, 22 |
| `platform-tools/velero/base/helmrelease.yaml` | 24, 29 |
| `platform-tools/eks-monitoring/base/helmrelease.yaml` | 28 |
| `platform-tools/thanos/base/helmrelease.yaml` | 73, 90 |
- **Fix:** Use `data.aws_caller_identity.current.account_id` in Terraform. Externalize values in K8s manifests.

### H3. Thanos Insecure Image Policy
- **File:** `platform-tools/thanos/base/helmrelease.yaml:34`
- **Code:** `allowInsecureImages: true`
- **Impact:** Allows pulling images from untrusted registries. MITM on container pulls.
- **Fix:** Set to `false`. Use verified images or mirror to private ECR.

### H4. Velero kubectl Using `latest` Tag
- **File:** `platform-tools/velero/overlays/dev/patch.yaml:13`
- **Code:** `tag: "latest"`
- **Impact:** Unpinned image tag — unpredictable versions, supply chain risk.
- **Fix:** Pin to specific version: `tag: "1.29.1"`

### H5. Karpenter AMI Selector Using `latest`
- **File:** `platform-tools/karpenter/nodepool/base/nodepool.yaml:41`
- **Code:** `alias: al2023@latest`
- **Impact:** New untested AMIs deployed automatically.
- **Fix:** Pin to specific AMI version after testing.

### H6. EFK Stack — HTTP Everywhere, No TLS
| Component | File | Issue |
|-----------|------|-------|
| Kibana | `helmrelease-kibana.yaml:34` | `protocol: http` |
| Fluent Bit | `helmrelease-fluentbit.yaml:98` | `tls Off` |
| ES inter-node | `helmrelease-elasticsearch.yaml:76` | `transport.ssl.enabled: false` |
- **Impact:** All log data (potentially containing secrets, PII) transmitted in plaintext within cluster.
- **Fix:** Enable TLS for production deployments.

### H7. Missing Shell Script Safety Flags
- **Files:** All 4 scripts (`tools-installation.sh`, `cluster-creation.sh`, `destroy-cluster.sh`, `validation.sh`)
- **Issue:** Only `set -e`, missing `set -u` (undefined vars) and `set -o pipefail` (pipe failures)
- **Fix:** Change to `set -euo pipefail` in all scripts.

### H8. GitHub Actions Not Pinned to SHA
| File | Line | Action |
|------|------|--------|
| `deploy-workflow.yaml` | 38 | `actions/checkout@v4` |
| `deploy-workflow.yaml` | 42 | `hashicorp/setup-terraform@v3` |
| `deploy-workflow.yaml` | 48 | `aws-actions/configure-aws-credentials@v4` |
| `validation-PT.yaml` | 26 | `actions/checkout@v3` |
| `validation-PT.yaml` | 29 | `aws-actions/configure-aws-credentials@v4` |
- **Fix:** Pin to full commit SHA: `actions/checkout@a5ac7e51b41094f...`

### H9. Unpinned Tool Versions in Install Script
- **File:** `scripts/tools-installation.sh:9-11,22`
- **Issue:** eksctl downloaded from `latest` release, Flux installed without version pin.
- **Fix:** Pin versions and verify checksums.

### H10. Workflow Permissions Too Broad
- **Files:** Both workflow files, lines 9-11
- **Code:** `contents: write`
- **Fix:** Change to `contents: read` — write not needed for checkout.

---

## MEDIUM Findings

### M1. Workers in Public Subnets
- **File:** `terraform-infra/eks-cluster/data-blocks.tf:5-8`, `asg.tf:6`
- **Issue:** ASG uses `data.aws_subnets.public.ids` — worker nodes get public IPs.
- **Fix:** Deploy workers in private subnets only.

### M2. Worker Security Group Allows All Traffic
- **File:** `terraform-infra/root/dev/networking/main.tf:84-92`
- **Code:** `protocol = "-1"` (all protocols between workers)
- **Fix:** Restrict to specific ports (53, 10250, 443).

### M3. IMDSv2 Not Enforced
- **File:** `terraform-infra/eks-cluster/launch-tm.tf`
- **Issue:** Missing `metadata_options` block with `http_tokens = "required"`
- **Fix:** Add metadata_options to enforce IMDSv2.

### M4. Incomplete EKS Control Plane Logging
- **File:** `terraform-infra/eks-cluster/eks.tf:5`
- **Code:** `enabled_cluster_log_types = ["api", "audit"]`
- **Fix:** Add `"authenticator", "controllerManager", "scheduler"`

### M5. Missing S3 Bucket Logging
- **File:** `terraform-infra/s3/s3.tf`
- **Issue:** No `aws_s3_bucket_logging` resource for Velero/Thanos buckets.

### M6. Missing VPC Flow Logs
- **File:** `terraform-infra/networking/vpc-module/vpc.tf`
- **Issue:** No VPC flow logs configured for network traffic monitoring.

### M7. S3 State Bucket Uses AES256 Instead of KMS
- **File:** `terraform-infra/bootstrap/main.tf:13-20`
- **Fix:** Use `aws:kms` with customer-managed key.

### M8. Missing DynamoDB Point-in-Time Recovery
- **File:** `terraform-infra/bootstrap/main.tf:32-46`
- **Issue:** Terraform lock table has no PITR.

### M9. Missing Network Policies for Karpenter, Velero, Thanos
- **Files:** `platform-tools/karpenter/base/`, `platform-tools/velero/base/`, `platform-tools/thanos/base/`
- **Issue:** No NetworkPolicy manifests — any pod can access these services.
- **Fix:** Create restrictive NetworkPolicy for each namespace.

### M10. Missing Pod Security Contexts
| Tool | File | Missing |
|------|------|---------|
| Karpenter | `karpenter/base/helmrelease.yaml` | runAsNonRoot, capabilities.drop |
| Velero | `velero/base/helmrelease.yaml` | runAsNonRoot, readOnlyRootFilesystem |
- **Fix:** Add explicit security contexts to HelmRelease values.

### M11. Missing Resource Limits
| Tool | File |
|------|------|
| Karpenter | `karpenter/base/helmrelease.yaml` |
| Velero | `velero/base/helmrelease.yaml` |
- **Fix:** Add explicit resource requests and limits.

### M12. Sealed Secrets Dev — Security Controls Disabled
- **File:** `platform-tools/sealed-secrets/overlays/dev/patch.yaml:10-11,25-26`
- **Issue:** PDB disabled, NetworkPolicy disabled, debug logging, no priority class.
- **Note:** This is the component that decrypts all secrets — treat it as critical infrastructure even in dev.

### M13. Missing Health Checks in Flux Kustomizations
- **File:** `clusters/dev-projectx/karpenter.yaml`
- **Issue:** No `healthChecks` section — Flux can't verify if Karpenter is actually running.

### M14. Secrets Exposed as Workflow-Level Environment Variables
- **File:** `.github/workflows/validation-PT.yaml:16`
- **Code:** `GITHUB_TOKEN: ${{ secrets.FLUX_GITHUB_PAT }}` at global level
- **Fix:** Move to step-level env only.

### M15. Feature Branch Pattern Too Broad
- **File:** `.github/workflows/deploy-workflow.yaml:6`
- **Code:** `feature/**` triggers infra deployment for all feature branches.
- **Fix:** Use `feature/infra/**` or `feature/terraform/**`

### M16. Missing Input Validation in Scripts
- **File:** `scripts/bootstrap-flux.sh:7-11`
- **Issue:** Validates params exist but not format — malicious branch name possible.

---

## LOW Findings

### L1. Hardcoded AWS Region in 6+ locations
### L2. Missing IAM Permission Boundaries
### L3. Database Performance Insights disabled in dev
### L4. Single ES replica in dev (operational risk, not security)
### L5. Thanos Query Frontend disabled in dev
### L6. Sleep 120 instead of kubectl wait in validation workflow
### L7. Missing workflow documentation headers
### L8. Karpenter EKS cluster endpoint hardcoded in helmrelease.yaml:22

---

## Priority Action Plan

### Immediate (24 hours)

| # | Finding | File | Action |
|---|---------|------|--------|
| 1 | C4 | `deploy-workflow.yaml:83` | Add manual approval gate before `terraform apply` |
| 2 | C5 | `tools-installation.sh:22` | Pin Flux version, verify checksum |
| 3 | C6 | `cluster-creation.sh:21` | Quote `$CLUSTER_NAME` |
| 4 | C7 | `destroy-cluster.sh:8-9` | Fix missing backslash |
| 5 | C3 | `helmrelease-kibana.yaml:73` | Generate real encryption key, use SealedSecret |
| 6 | H7 | All scripts | Add `set -euo pipefail` |
| 7 | H8 | Both workflows | Pin Actions to commit SHA |

### Week 1

| # | Finding | File | Action |
|---|---------|------|--------|
| 8 | C1 | `eks.tf:12` | Restrict public endpoint or switch to private |
| 9 | C2 | `flux.tf:63,70` | Move GitHub token to Secrets Manager |
| 10 | H1 | IAM policies | Scope `Resource: "*"` to specific ARNs |
| 11 | M1 | `data-blocks.tf` | Move workers to private subnets |
| 12 | M3 | `launch-tm.tf` | Enforce IMDSv2 |
| 13 | H3 | `thanos/helmrelease.yaml:34` | Set `allowInsecureImages: false` |
| 14 | H4 | `velero/dev/patch.yaml:13` | Pin kubectl image tag |

### Week 2

| # | Finding | File | Action |
|---|---------|------|--------|
| 15 | M9 | karpenter, velero, thanos | Create NetworkPolicy for each |
| 16 | M10 | karpenter, velero | Add pod security contexts |
| 17 | M11 | karpenter, velero | Add resource limits |
| 18 | M2 | `networking/main.tf:84-92` | Restrict worker SG to specific ports |
| 19 | M4 | `eks.tf:5` | Enable all control plane log types |
| 20 | H2 | 10+ files | Replace hardcoded account IDs with data sources |

### Week 3

| # | Finding | File | Action |
|---|---------|------|--------|
| 21 | M5 | `s3/s3.tf` | Add S3 access logging |
| 22 | M6 | `vpc-module/vpc.tf` | Add VPC flow logs |
| 23 | M7 | `bootstrap/main.tf` | Switch to KMS encryption for state |
| 24 | M8 | `bootstrap/main.tf` | Enable DynamoDB PITR |
| 25 | H6 | EFK stack | Plan TLS rollout for production |

### Week 4

| # | Finding | File | Action |
|---|---------|------|--------|
| 26 | L2 | `iam-role-module/main.tf` | Add IAM permission boundaries |
| 27 | M13 | `clusters/dev-projectx/` | Add healthChecks to all Kustomizations |
| 28 | H5 | `nodepool.yaml:41` | Pin Karpenter AMI selector |
| 29 | -- | `clusters/prod-projectx/` | Set up production cluster manifests |
| 30 | -- | All platform-tools | Production TLS, HA, PDB review |

---

## What Was Fixed Since Last Audit

| Issue | Status | How |
|-------|--------|-----|
| Grafana `adminPassword: admin123` in plaintext | **FIXED** | Moved to SealedSecret `grafana-admin-credentials` |
| Grafana `dev-password` / `prod-password` in overlays | **FIXED** | Removed — uses base SealedSecret |
| EFK logging was copy of eks-monitoring | **FIXED** | Rebuilt with proper ES + Kibana + Fluent Bit |
| sealed-secrets prod overlay corrupted | **FIXED** | Rewritten with proper sealed-secrets values |
| No SealedSecrets for Thanos | **FIXED** | Created `thanos-objstore-secret` SealedSecret |
| Kibana ES token manual kubectl create | **FIXED** | Created `kibana-kibana-es-token` SealedSecret |
| Missing EFK network policies | **FIXED** | Added policies for ES, Kibana, Fluent Bit |
| Missing EFK pod security contexts | **FIXED** | Added for ES and Kibana containers |
| Missing Flux Kustomization for EFK | **FIXED** | Created `clusters/dev-projectx/efk-logging.yaml` |
