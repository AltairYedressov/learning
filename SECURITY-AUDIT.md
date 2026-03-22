# Security Audit Report -- ProjectX EKS Platform

**Date:** 2026-03-22
**Scope:** Full repository audit covering Terraform infrastructure, Kubernetes platform tools, CI/CD workflows, and shell scripts.
**Auditor:** Automated security review

---

## Executive Summary

The ProjectX EKS platform has **6 critical**, **10 high**, and **7 medium** severity findings. The most urgent issues are **hardcoded passwords committed to Git** (6 locations), **EKS worker nodes deployed in public subnets**, and **wildcard IAM policies** that grant overly broad permissions.

The platform demonstrates good practices in several areas -- OIDC-based authentication for GitHub Actions, SealedSecrets for secret management, and a well-structured GitOps workflow with Flux. However, the security posture has significant gaps that need immediate attention before this platform should handle production workloads.

**Overall Risk: HIGH**

| Severity | Count | Status |
|----------|-------|--------|
| Critical | 6 | Fix immediately |
| High | 10 | Fix this week |
| Medium | 7 | Fix this sprint |
| **Total** | **23** | |

---

## Critical Findings

These findings represent active security risks that should be addressed immediately.

---

### CRITICAL-1: Hardcoded Passwords in Git (6 Locations)

**Severity:** CRITICAL
**Impact:** Anyone with read access to the repository has admin credentials for Grafana and Elasticsearch across all environments. Credentials in Git history persist even after deletion.

**Affected Files:**

| # | File | Line | Password |
|---|------|------|----------|
| 1 | `platform-tools/eks-monitoring/base/helmrelease.yaml` | 19 | `adminPassword: admin123` |
| 2 | `platform-tools/eks-monitoring/overlays/dev/patch.yaml` | 20 | `adminPassword: dev-password` |
| 3 | `platform-tools/eks-monitoring/overlays/prod/patch.yaml` | 20 | `adminPassword: prod-password` |
| 4 | `platform-tools/efk-logging/base/helmrelease.yaml` | 19 | `adminPassword: admin123` |
| 5 | `platform-tools/efk-logging/overlays/dev/patch.yaml` | 20 | `adminPassword: dev-password` |
| 6 | `platform-tools/efk-logging/overlays/prod/patch.yaml` | 20 | `adminPassword: prod-password` |

**Remediation:**
1. Rotate all passwords immediately (assume they are compromised).
2. Create SealedSecret resources for each password (the sealed-secrets controller is already deployed).
3. Reference the secrets using `existingSecret` in the HelmRelease values instead of inline passwords.
4. Run `git filter-repo` or BFG Repo-Cleaner to purge passwords from Git history.
5. Force-push the cleaned history and notify all contributors to re-clone.

---

### CRITICAL-2: EKS Worker Nodes in Public Subnets

**Severity:** CRITICAL
**Impact:** Worker nodes receive public IP addresses and are directly reachable from the internet. An attacker can scan for exposed ports, exploit unpatched vulnerabilities, or perform lateral movement into the cluster.

**Affected Files:**

| File | Line | Issue |
|------|------|-------|
| `terraform-infra/eks-cluster/asg.tf` | 6 | `vpc_zone_identifier = data.aws_subnets.public.ids` |
| `terraform-infra/eks-cluster/eks.tf` | 13 | `subnet_ids = data.aws_subnets.public.ids` |
| `terraform-infra/eks-cluster/data-blocks.tf` | 5-9 | Data source filters for `Type: public` subnets only |
| `platform-tools/karpenter/nodepool/base/nodepool.yaml` | 44-45 | `subnetSelectorTerms` selects `Type: public` subnets |

**Remediation:**
1. Move worker nodes to private subnets (already defined in networking `terraform.tfvars`: `10.0.4.0/24`, `10.0.5.0/24`, `10.0.6.0/24`).
2. Add a NAT Gateway to the networking stack so private-subnet workers can pull container images.
3. Update `data.aws_subnets` to filter for `Type: private` instead of `Type: public`.
4. Update Karpenter `subnetSelectorTerms` to `Type: private`.
5. Keep the EKS control plane endpoint on public subnets (or switch to private endpoint with VPN).

---

### CRITICAL-3: Wildcard IAM Policies (Resource: "*")

**Severity:** CRITICAL
**Impact:** Overly broad IAM permissions allow lateral movement and privilege escalation. A compromised pod with IRSA access could enumerate and modify resources across the entire AWS account.

**Affected Files:**

| File | Line(s) | Wildcard Actions |
|------|---------|-----------------|
| `terraform-infra/iam-role-module/Policies/karpenter_policy.json` | 24 | 13 EC2 actions on `Resource: "*"` |
| `terraform-infra/iam-role-module/Policies/karpenter_policy.json` | 38 | 7 IAM instance profile actions on `Resource: "*"` |
| `terraform-infra/iam-role-module/Policies/karpenter_policy.json` | 63 | `pricing:GetProducts` on `Resource: "*"` |
| `terraform-infra/iam-role-module/Policies/velero_policy.json` | 14 | 6 EC2 volume/snapshot actions on `Resource: "*"` |
| `terraform-infra/root/dev/iam-roles/variables.tf` | 22 | Worker node role has `AmazonEC2FullAccess` managed policy |

**Remediation:**
1. Scope Karpenter EC2 actions to the cluster VPC using `ec2:Vpc` condition key, or restrict `Resource` to specific ARN patterns with cluster tags.
2. Scope Karpenter IAM actions to instance profiles with a name prefix (e.g., `arn:aws:iam::*:instance-profile/projectx-*`).
3. Scope Velero EC2 actions to volumes/snapshots tagged with the cluster name.
4. **Remove `AmazonEC2FullAccess`** from the worker node role. This grants full EC2 API access to every pod on the worker node. Replace with only the specific permissions needed (EKS worker node policy, CNI policy, ECR read-only).

---

### CRITICAL-4: Hardcoded AWS Account ID and OIDC URL

**Severity:** CRITICAL
**Impact:** Information disclosure -- the AWS account ID (`372517046622`) and OIDC provider URL are hardcoded in 10+ files. This prevents multi-account deployment, makes rotation impossible, and exposes the account ID to anyone with repo access.

**Affected Files:**

| File | Line(s) | Hardcoded Value |
|------|---------|-----------------|
| `terraform-infra/eks-cluster/access-entries.tf` | 9, 15, 16, 24, 30 | `372517046622` (account ID) |
| `terraform-infra/iam-role-module/Policies/karpenter_policy.json` | 44, 50 | `372517046622` (account ID) |
| `terraform-infra/iam-role-module/Policies/velero_policy.json` | 25, 32 | `372517046622` (bucket name) |
| `terraform-infra/iam-role-module/Policies/thanos_policy.json` | 13, 21 | `372517046622` (bucket name) |
| `terraform-infra/root/dev/iam-roles/data-blocks.tf` | 3 | Hardcoded OIDC URL with cluster-specific ID |
| `terraform-infra/root/dev/s3/main.tf` | 4, 22 | `372517046622` (bucket name) |
| `platform-tools/karpenter/base/helmrelease.yaml` | 19, 22 | Account ID in role ARN, cluster endpoint URL |
| `platform-tools/velero/base/helmrelease.yaml` | 24, 29 | Account ID in role ARN, bucket name |
| `platform-tools/velero/overlays/dev/patch.yaml` | 24 | Account ID in bucket name |
| `platform-tools/thanos/base/helmrelease.yaml` | 73, 90 | Account ID in role ARNs |

**Remediation:**
1. Use Terraform `data.aws_caller_identity.current.account_id` to dynamically resolve the account ID.
2. Pass account ID, OIDC URL, and bucket names as Terraform variables.
3. For Kubernetes manifests, use Flux variable substitution or Kustomize `configMapGenerator` to inject account-specific values at deploy time.
4. Use Terraform outputs from the `iam-roles` and `s3` stacks as inputs to the `eks` stack.

---

### CRITICAL-5: `terraform apply -auto-approve` in CI

**Severity:** CRITICAL
**Impact:** Infrastructure changes are applied automatically on merge to `main` with no human review of the Terraform plan output. A misconfigured Terraform change could destroy the production cluster, delete data, or create security vulnerabilities.

**Affected File:**

| File | Line | Issue |
|------|------|-------|
| `.github/workflows/deploy-workflow.yaml` | 83 | `terraform apply -auto-approve -input=false` |

**Remediation:**
1. Split the workflow into two jobs: `plan` and `apply`.
2. The `plan` job should save the plan to an artifact (`terraform plan -out=tfplan`).
3. The `apply` job should require **manual approval** via a GitHub Environment protection rule.
4. The `apply` job consumes the saved plan artifact (`terraform apply tfplan`).
5. Optionally, post the plan diff as a PR comment for review before merge.

---

### CRITICAL-6: `curl | sudo bash` in Scripts

**Severity:** CRITICAL
**Impact:** Supply chain attack vector. The `tools-installation.sh` script pipes remote content directly to `sudo bash`. If the remote server is compromised (DNS hijack, CDN compromise, man-in-the-middle), arbitrary code runs as root on the CI runner.

**Affected File:**

| File | Line | Issue |
|------|------|-------|
| `scripts/tools-installation.sh` | 22 | `curl -s https://fluxcd.io/install.sh \| sudo bash` |

**Remediation:**
1. Pin tool versions explicitly (already done for kubectl, not for eksctl or Flux).
2. Download the binary, verify its checksum against a known-good value, then install.
3. For Flux, use a specific version: `curl -s https://fluxcd.io/install.sh | FLUX_VERSION=2.4.0 sudo bash` or download the binary directly from GitHub releases and verify the checksum.
4. For eksctl, pin to a specific version instead of `latest`.

---

## High Findings

These findings should be addressed within the current week.

---

### HIGH-1: Missing Pod Security Contexts

**Severity:** HIGH
**Impact:** Containers run as root by default, which increases the blast radius if a container is compromised. An attacker gaining code execution inside a root container can escape to the host more easily.

The `sealed-secrets` HelmRelease is the only platform tool with proper security contexts configured (runAsNonRoot, drop ALL capabilities, readOnlyRootFilesystem, seccomp profile).

**Affected Tools:**

| Tool | File |
|------|------|
| eks-monitoring (kube-prometheus-stack) | `platform-tools/eks-monitoring/base/helmrelease.yaml` |
| efk-logging | `platform-tools/efk-logging/base/helmrelease.yaml` |
| karpenter | `platform-tools/karpenter/base/helmrelease.yaml` |
| velero | `platform-tools/velero/base/helmrelease.yaml` |
| thanos | `platform-tools/thanos/base/helmrelease.yaml` |

**Remediation:** Add pod and container security contexts to each HelmRelease values:
```yaml
podSecurityContext:
  runAsNonRoot: true
  fsGroup: 65534
  seccompProfile:
    type: RuntimeDefault
containerSecurityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: [ALL]
```

---

### HIGH-2: Missing Network Policies

**Severity:** HIGH
**Impact:** Without network policies, any pod in the cluster can communicate with any other pod. A compromised pod in one namespace can reach databases, monitoring backends, and secrets controllers in other namespaces.

Only `sealed-secrets` has a network policy defined (`platform-tools/sealed-secrets/base/networkpolicy.yaml`).

**Affected Tools:**

| Tool | Namespace |
|------|-----------|
| eks-monitoring | monitoring |
| efk-logging | logging |
| karpenter | karpenter |
| velero | velero |

**Remediation:** Create `NetworkPolicy` resources for each namespace that default-deny all ingress/egress, then allow only required communication paths.

---

### HIGH-3: Missing Resource Limits

**Severity:** HIGH
**Impact:** Pods without resource limits can consume all CPU and memory on a node, causing node instability, OOM kills of other pods, and potential denial of service.

`sealed-secrets` and `thanos` have resource limits defined. The following do not:

| Tool | File |
|------|------|
| eks-monitoring | `platform-tools/eks-monitoring/base/helmrelease.yaml` |
| efk-logging | `platform-tools/efk-logging/base/helmrelease.yaml` |
| karpenter | `platform-tools/karpenter/base/helmrelease.yaml` |
| velero | `platform-tools/velero/base/helmrelease.yaml` |

**Remediation:** Add `resources.requests` and `resources.limits` for CPU and memory in each HelmRelease values block.

---

### HIGH-4: Missing PodDisruptionBudgets for Production

**Severity:** HIGH
**Impact:** Without PDBs, Kubernetes can evict all replicas of a deployment simultaneously during node drains, upgrades, or Karpenter consolidation, causing service outages.

Only `sealed-secrets` has a PDB configured. The production overlays for all other tools do not define PDBs.

**Affected Files:**
- `platform-tools/eks-monitoring/overlays/prod/patch.yaml`
- `platform-tools/efk-logging/overlays/prod/patch.yaml`
- `platform-tools/karpenter/overlays/prod/patch.yaml`
- `platform-tools/velero/overlays/prod/patch.yaml`
- `platform-tools/thanos/overlays/prod/patch.yaml`

**Remediation:** Add `podDisruptionBudget` configuration to each production overlay with `minAvailable: 1` or `maxUnavailable: 1`.

---

### HIGH-5: `allowInsecureImages` Enabled in Thanos

**Severity:** HIGH
**Impact:** The Thanos HelmRelease sets `global.security.allowInsecureImages: true`, disabling image signature verification. This allows pulling unverified images that could contain malicious code.

**Affected File:**

| File | Line | Issue |
|------|------|-------|
| `platform-tools/thanos/base/helmrelease.yaml` | 34 | `allowInsecureImages: true` |

**Remediation:** Remove `allowInsecureImages: true` or set it to `false`. If specific images fail verification, investigate and fix the image source rather than disabling verification.

---

### HIGH-6: GitHub Token Exposed in Terraform State

**Severity:** HIGH
**Impact:** The Flux provider in `terraform-infra/eks-cluster/flux.tf` uses `var.github_token` directly. While marked as `sensitive`, Terraform stores all provider configuration in the state file. Anyone with access to the S3 state bucket can extract the GitHub PAT.

**Affected Files:**

| File | Line(s) | Issue |
|------|---------|-------|
| `terraform-infra/eks-cluster/flux.tf` | 63-64 | `password = var.github_token` in provider config |
| `.github/workflows/deploy-workflow.yaml` | 76, 85 | `TF_VAR_github_token: ${{ secrets.FLUX_GITHUB_PAT }}` |

**Remediation:**
1. Encrypt the Terraform state bucket with AWS KMS (currently uses AES256).
2. Restrict access to the state bucket to only the CI role.
3. Consider bootstrapping Flux outside of Terraform using the `flux bootstrap` CLI in a separate workflow step, avoiding the token in state entirely.

---

### HIGH-7: Worker Security Group Allows All Internal Traffic

**Severity:** HIGH
**Impact:** The self-referencing security group rule allows all protocols and all ports between worker nodes. This provides no network-level segmentation between pods running on different nodes.

**Affected File:**

| File | Line(s) | Issue |
|------|---------|-------|
| `terraform-infra/root/dev/networking/main.tf` | 84-92 | `protocol = "-1"` (all protocols), `from_port = 0`, `to_port = 0` self-referencing rule |

**Remediation:** Replace the catch-all rule with specific rules:
- TCP 10250 (kubelet)
- TCP/UDP 53 (CoreDNS)
- Pod CIDR range for overlay networking
- TCP 443 for webhook communication

---

### HIGH-8: Shell Scripts Missing Safety Options

**Severity:** HIGH
**Impact:** Most scripts use `set -e` but none use `set -u` (fail on undefined variables) or `set -o pipefail` (fail on pipe errors). This can mask failures -- for example, `scripts/destroy-cluster.sh` also has a syntax error (missing `\` continuation on line 9) that could prevent cleanup.

**Affected Files:**

| File | Issue |
|------|-------|
| `scripts/tools-installation.sh` | Missing `set -u` and `set -o pipefail` |
| `scripts/cluster-creation.sh` | Missing `set -u` and `set -o pipefail` |
| `scripts/destroy-cluster.sh` | Missing `set -u` and `set -o pipefail`; syntax error on line 9 (missing `\` before `--wait`) |
| `scripts/validation.sh` | Missing `set -u` and `set -o pipefail` |
| `scripts/bootstrap-flux.sh` | Missing `set -u` and `set -o pipefail` |

**Remediation:** Add `set -euo pipefail` to the top of every script. Fix the syntax error in `destroy-cluster.sh`.

---

### HIGH-9: Empty Production Cluster Directory

**Severity:** HIGH
**Impact:** There is no `clusters/prod-projectx/` or `clusters/prod/` directory. The production Terraform root modules exist (`terraform-infra/root/prod/`) but there is no Flux cluster configuration to deploy platform tools to a production cluster. Production is effectively not configured.

**Remediation:**
1. Create `clusters/prod-projectx/` with Kustomization resources for each platform tool pointing to the `overlays/prod/` paths.
2. Review and fix all prod overlay files (several are duplicates of the dev overlays with incorrect content -- see HIGH-10).

---

### HIGH-10: Broken Production Overlay Files

**Severity:** HIGH
**Impact:** Several production overlay files contain the exact same content as dev overlays (with a dev comment header) or have clearly wrong values for production use.

**Affected Files:**

| File | Issue |
|------|-------|
| `platform-tools/efk-logging/overlays/prod/patch.yaml` | Contains `# platform-tools/eks-monitoring/overlays/prod/patch.yaml` comment but is for efk-logging |
| `platform-tools/velero/overlays/prod/patch.yaml` | Missing entirely -- only the karpenter prod overlay exists at this path |
| `platform-tools/sealed-secrets/overlays/prod/patch.yaml` | Contains same monitoring comment header as the dev overlay |

**Remediation:** Review and correct all production overlay files to have appropriate production values.

---

## Medium Findings

These findings should be addressed within the current sprint.

---

### MEDIUM-1: GitHub Actions Not Pinned to SHA

**Severity:** MEDIUM
**Impact:** Actions referenced by tag (`@v3`, `@v4`) can be silently updated by the action maintainer. A compromised action could exfiltrate secrets or inject malicious code.

**Affected File:**

| File | Line | Action |
|------|------|--------|
| `.github/workflows/deploy-workflow.yaml` | 38 | `actions/checkout@v4` |
| `.github/workflows/deploy-workflow.yaml` | 42 | `hashicorp/setup-terraform@v3` |
| `.github/workflows/deploy-workflow.yaml` | 48 | `aws-actions/configure-aws-credentials@v4` |
| `.github/workflows/validation-PT.yaml` | 26 | `actions/checkout@v3` |
| `.github/workflows/validation-PT.yaml` | 29 | `aws-actions/configure-aws-credentials@v4` |

**Remediation:** Pin all actions to their full commit SHA:
```yaml
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4.1.1
```

---

### MEDIUM-2: Unpinned Helm Chart Versions

**Severity:** MEDIUM
**Impact:** Wildcard chart versions (e.g., `58.x.x`, `1.x.x`, `15.x.x`) allow automatic upgrades to new minor/patch versions that may introduce breaking changes or vulnerabilities.

**Affected Files:**

| File | Chart | Version |
|------|-------|---------|
| `platform-tools/eks-monitoring/base/helmrelease.yaml` | kube-prometheus-stack | `58.x.x` |
| `platform-tools/efk-logging/base/helmrelease.yaml` | kube-prometheus-stack | `58.x.x` |
| `platform-tools/karpenter/base/helmrelease.yaml` | karpenter | `1.x.x` |
| `platform-tools/thanos/base/helmrelease.yaml` | thanos | `15.x.x` |
| `platform-tools/sealed-secrets/base/helmrelease.yaml` | sealed-secrets | `>=2.16.0 <3.0.0` |

**Remediation:** Pin to exact versions (e.g., `58.7.2` instead of `58.x.x`). Use Renovate or Dependabot to manage version updates via pull requests.

---

### MEDIUM-3: Velero Uses `latest` Image Tag

**Severity:** MEDIUM
**Impact:** The `latest` tag is mutable -- it can point to different image digests at different times. This breaks reproducibility and could introduce untested changes.

**Affected File:**

| File | Line | Issue |
|------|------|-------|
| `platform-tools/velero/overlays/dev/patch.yaml` | 13 | `tag: "latest"` for kubectl image |

**Remediation:** Pin to a specific version tag or image digest.

---

### MEDIUM-4: S3 State Bucket Uses AES256 Instead of KMS

**Severity:** MEDIUM
**Impact:** AES256 (SSE-S3) encryption is managed entirely by AWS with no customer control over the key. KMS provides key rotation, access logging via CloudTrail, and the ability to revoke access by disabling the key.

**Affected File:**

| File | Line | Issue |
|------|------|-------|
| `terraform-infra/bootstrap/main.tf` | 17 | `sse_algorithm = "AES256"` |

**Remediation:** Switch to KMS encryption:
```hcl
sse_algorithm     = "aws:kms"
kms_master_key_id = aws_kms_key.terraform_state.arn
```

---

### MEDIUM-5: IMDSv2 Not Enforced on Worker Nodes

**Severity:** MEDIUM
**Impact:** Without enforcing IMDSv2 (Instance Metadata Service v2), worker nodes are vulnerable to SSRF attacks that can steal IAM role credentials from the instance metadata endpoint.

**Affected File:**

| File | Issue |
|------|-------|
| `terraform-infra/eks-cluster/launch-tm.tf` | No `metadata_options` block in the launch template |

**Remediation:** Add to the launch template:
```hcl
metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "required"  # Enforces IMDSv2
  http_put_response_hop_limit = 1
}
```

---

### MEDIUM-6: Missing S3 Access Logging

**Severity:** MEDIUM
**Impact:** Without access logging, there is no audit trail for who accessed the Terraform state bucket, Velero backup bucket, or Thanos metrics bucket. Compromised state or deleted backups cannot be investigated.

**Affected Files:**
- `terraform-infra/bootstrap/main.tf` (state bucket)
- `terraform-infra/s3/s3.tf` (generic S3 module -- no logging configuration)

**Remediation:** Create a dedicated logging bucket and enable S3 server access logging on all buckets.

---

### MEDIUM-7: Missing CloudTrail

**Severity:** MEDIUM
**Impact:** Without CloudTrail, there is no audit log for AWS API calls. Security incidents (IAM key compromise, unauthorized access, resource deletion) cannot be detected or investigated.

**Affected:** No CloudTrail configuration exists anywhere in the repository.

**Remediation:** Add a Terraform module that creates a CloudTrail trail with:
- Multi-region enabled
- Log file validation enabled
- Logs stored in a dedicated S3 bucket with lifecycle policies
- Integration with CloudWatch Logs for alerting

---

## Priority Action Plan

| Priority | Finding | File(s) | Fix | Impact if Not Fixed |
|----------|---------|---------|-----|---------------------|
| P0 | CRITICAL-1: Hardcoded passwords | `eks-monitoring/base/helmrelease.yaml:19`, `eks-monitoring/overlays/dev/patch.yaml:20`, `eks-monitoring/overlays/prod/patch.yaml:20`, `efk-logging/base/helmrelease.yaml:19`, `efk-logging/overlays/dev/patch.yaml:20`, `efk-logging/overlays/prod/patch.yaml:20` | Rotate passwords, use SealedSecrets, purge Git history | Full admin access to Grafana/ES for anyone with repo access |
| P0 | CRITICAL-2: Public subnets | `eks-cluster/asg.tf:6`, `eks-cluster/eks.tf:13`, `eks-cluster/data-blocks.tf:5-9`, `karpenter/nodepool/base/nodepool.yaml:44-45` | Move workers to private subnets, add NAT Gateway | Worker nodes exposed to internet, direct attack surface |
| P0 | CRITICAL-3: Wildcard IAM | `Policies/karpenter_policy.json:24,38,63`, `Policies/velero_policy.json:14`, `root/dev/iam-roles/variables.tf:22` | Scope resources, remove EC2FullAccess | Account-wide lateral movement from compromised pod |
| P0 | CRITICAL-4: Hardcoded account ID | `access-entries.tf:9,15,24,30`, `karpenter_policy.json:44,50`, `velero_policy.json:25,32`, `thanos_policy.json:13,21`, `iam-roles/data-blocks.tf:3`, `s3/main.tf:4,22`, `karpenter/helmrelease.yaml:19,22`, `velero/helmrelease.yaml:24,29`, `thanos/helmrelease.yaml:73,90` | Use data sources and variables | Info disclosure, prevents multi-account, breaks portability |
| P0 | CRITICAL-5: Auto-approve | `.github/workflows/deploy-workflow.yaml:83` | Add manual approval gate via GitHub Environments | Unreviewed infra changes can destroy resources |
| P0 | CRITICAL-6: curl pipe bash | `scripts/tools-installation.sh:22` | Pin versions, verify checksums | Supply chain attack on CI runner |
| P1 | HIGH-1: No security contexts | `eks-monitoring/base/helmrelease.yaml`, `efk-logging/base/helmrelease.yaml`, `karpenter/base/helmrelease.yaml`, `velero/base/helmrelease.yaml`, `thanos/base/helmrelease.yaml` | Add podSecurityContext and containerSecurityContext | Root container escape to host |
| P1 | HIGH-2: No network policies | monitoring, logging, karpenter, velero namespaces | Create NetworkPolicy for each namespace | Unrestricted lateral movement between pods |
| P1 | HIGH-3: No resource limits | `eks-monitoring/base/helmrelease.yaml`, `efk-logging/base/helmrelease.yaml`, `karpenter/base/helmrelease.yaml`, `velero/base/helmrelease.yaml` | Add resources.requests and resources.limits | Node resource exhaustion, OOM kills |
| P1 | HIGH-4: No PDBs | All prod overlays except sealed-secrets | Add podDisruptionBudget to prod overlays | Service outage during node drains/upgrades |
| P1 | HIGH-5: Insecure images | `thanos/base/helmrelease.yaml:34` | Remove `allowInsecureImages: true` | Unverified images can contain malicious code |
| P1 | HIGH-6: Token in state | `eks-cluster/flux.tf:63-64` | Encrypt state with KMS, or bootstrap Flux outside Terraform | GitHub PAT exposed to state bucket readers |
| P1 | HIGH-7: Permissive SG | `root/dev/networking/main.tf:84-92` | Replace all-traffic rule with specific port rules | No network segmentation between nodes |
| P1 | HIGH-8: Script safety | `scripts/*.sh` | Add `set -euo pipefail`, fix syntax error in `destroy-cluster.sh:9` | Silent failures, orphaned resources |
| P1 | HIGH-9: No prod cluster | Missing `clusters/prod-projectx/` directory | Create prod cluster Flux kustomizations | Production has no GitOps configuration |
| P1 | HIGH-10: Broken prod overlays | Various prod `patch.yaml` files | Review and correct all prod overlays | Production deploys with wrong configuration |
| P2 | MEDIUM-1: Unpinned Actions | `.github/workflows/deploy-workflow.yaml:38,42,48`, `.github/workflows/validation-PT.yaml:26,29` | Pin to commit SHA | Compromised action can exfiltrate secrets |
| P2 | MEDIUM-2: Unpinned charts | `eks-monitoring/base/helmrelease.yaml`, `efk-logging/base/helmrelease.yaml`, `karpenter/base/helmrelease.yaml`, `thanos/base/helmrelease.yaml`, `sealed-secrets/base/helmrelease.yaml` | Pin to exact versions | Unexpected breaking changes |
| P2 | MEDIUM-3: Latest tag | `velero/overlays/dev/patch.yaml:13` | Pin to specific version | Non-reproducible deployments |
| P2 | MEDIUM-4: AES256 state | `terraform-infra/bootstrap/main.tf:17` | Switch to KMS encryption | No key management or rotation control |
| P2 | MEDIUM-5: No IMDSv2 | `terraform-infra/eks-cluster/launch-tm.tf` | Add `metadata_options` with `http_tokens = "required"` | SSRF can steal instance role credentials |
| P2 | MEDIUM-6: No S3 logging | `terraform-infra/bootstrap/main.tf`, `terraform-infra/s3/s3.tf` | Enable S3 server access logging | No audit trail for bucket access |
| P2 | MEDIUM-7: No CloudTrail | Repository-wide (missing) | Add CloudTrail Terraform module | No API audit log, incidents undetectable |

---

## Remediation Timeline

### Immediate (24 hours)

- [ ] **Rotate all hardcoded passwords** (Grafana admin, Elasticsearch admin) across all environments
- [ ] **Remove `AmazonEC2FullAccess`** from the worker node role (`terraform-infra/root/dev/iam-roles/variables.tf:22`)
- [ ] **Create SealedSecrets** for Grafana and Elasticsearch passwords; update HelmRelease values to reference them
- [ ] **Purge passwords from Git history** using BFG Repo-Cleaner or `git filter-repo`

### Week 1

- [ ] Move EKS workers to private subnets (update `data-blocks.tf`, `asg.tf`, `eks.tf`, Karpenter nodepool)
- [ ] Add NAT Gateway to the networking stack
- [ ] Scope Karpenter IAM policy resources (replace `Resource: "*"` with ARN patterns)
- [ ] Scope Velero IAM policy EC2 resources (tag-based conditions)
- [ ] Replace hardcoded account IDs with Terraform data sources
- [ ] Add pod security contexts to all HelmRelease values
- [ ] Add `metadata_options` with IMDSv2 enforcement to the launch template

### Week 2

- [ ] Create NetworkPolicy resources for monitoring, logging, karpenter, and velero namespaces
- [ ] Add resource limits to eks-monitoring, efk-logging, karpenter, and velero HelmReleases
- [ ] Add PodDisruptionBudgets to all production overlays
- [ ] Fix the self-referencing worker security group rule (replace all-traffic with specific ports)
- [ ] Add `set -euo pipefail` to all shell scripts; fix `destroy-cluster.sh` syntax error
- [ ] Remove `allowInsecureImages: true` from Thanos HelmRelease

### Week 3

- [ ] Add manual approval gate to the Terraform deploy workflow (GitHub Environments)
- [ ] Pin all GitHub Actions to commit SHAs
- [ ] Pin Flux CLI and eksctl to specific versions with checksum verification
- [ ] Switch Terraform state bucket encryption from AES256 to KMS
- [ ] Enable S3 server access logging on all buckets
- [ ] Add CloudTrail Terraform module
- [ ] Pin all Helm chart versions to exact versions
- [ ] Replace `latest` tag in Velero kubectl image with specific version

### Week 4

- [ ] Create `clusters/prod-projectx/` directory with all Kustomization resources
- [ ] Review and fix all production overlay files
- [ ] Pin container images to digest (SHA256) for production
- [ ] Set up Renovate or Dependabot for automated version update PRs
- [ ] Consider bootstrapping Flux outside of Terraform to avoid token in state
- [ ] Conduct follow-up audit to verify all findings are resolved
