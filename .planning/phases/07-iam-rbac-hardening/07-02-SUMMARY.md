---
phase: 07-iam-rbac-hardening
plan: 02
subsystem: infra
tags: [rbac, iam, irsa, eks, kubernetes, sealed-secrets, audit]

# Dependency graph
requires:
  - phase: 07-iam-rbac-hardening/01
    provides: "Kyverno deny-default NetworkPolicy, PSS Restricted audit baseline"
provides:
  - "RBAC ClusterRoleBinding inventory with justifications"
  - "IRSA custom policy audit for all 4 roles"
  - "EKS access entry documentation"
  - "Sealed-secrets RBAC inline security comments"
affects: [08-cicd-gitops]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Inline YAML security justification comments per D-12"]

key-files:
  created: []
  modified: ["platform-tools/sealed-secrets/base/RBAC.yaml"]

key-decisions:
  - "No IRSA policy changes needed -- all 4 custom policies are well-scoped with resource ARN constraints"
  - "No system:masters bindings in git-managed manifests confirmed"
  - "Karpenter iam:CreateInstanceProfile on Resource:* accepted as required for dynamic instance profile management"
  - "AWS LB Controller waf-regional/shield permissions accepted as canonical inclusion"

patterns-established:
  - "RBAC manifests include Purpose and Security justification comment blocks"
  - "IRSA audit documented per-role with flags for non-scoped resources"

requirements-completed: [IAM-01, IAM-02]

# Metrics
duration: 3min
completed: 2026-03-29
---

# Phase 7 Plan 2: RBAC and IRSA Audit Summary

**Comprehensive RBAC ClusterRoleBinding inventory, IRSA custom policy review for 4 roles, and EKS access entry documentation confirming least-privilege across all git-managed bindings**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-29T17:46:37Z
- **Completed:** 2026-03-29T17:49:00Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Enhanced sealed-secrets RBAC.yaml with inline security justification comments per D-12
- Audited all 3 git-managed ClusterRoleBindings with documented justifications
- Reviewed all 4 IRSA custom policies confirming minimal permissions with resource ARN scoping
- Documented all 3 EKS access entries with justification per D-06/D-07/D-08
- Confirmed no system:masters bindings exist in git-managed manifests

## Task Commits

Each task was committed atomically:

1. **Task 1: Enhance sealed-secrets RBAC.yaml with inline justification comments** - `64549a5` (docs)
2. **Task 2: Produce RBAC and IRSA audit report in phase summary** - (this file, committed with metadata)

## Files Created/Modified
- `platform-tools/sealed-secrets/base/RBAC.yaml` - Added Phase 7 IAM-01 security justification comments to ClusterRole and ClusterRoleBinding

## RBAC ClusterRoleBinding Inventory (IAM-01)

All git-managed ClusterRoleBindings in the codebase:

| Name | ClusterRole | Subjects | Source | Justification |
|------|-------------|----------|--------|---------------|
| cluster-reconciler-flux-system | cluster-admin | SA: kustomize-controller (flux-system) | gotk-components.yaml | Flux kustomize-controller needs full cluster access to reconcile any resource type across all namespaces. Required for GitOps operation. Accepted per D-14/D-15 |
| crd-controller-flux-system | crd-controller-flux-system (custom) | SA: helm-controller, kustomize-controller, notification-controller, source-controller (flux-system) | gotk-components.yaml | Flux controllers need CRD management. Custom role (not cluster-admin) -- grants only CRD CRUD and namespace listing |
| sealed-secrets-reader-binding | sealed-secrets-reader (custom) | Group: platform-ops | RBAC.yaml | Read-only SealedSecret CR inspection. Cannot read decrypted Secrets. Enhanced with inline comments per D-12 |

Note per D-13: Helm-managed CRBs (sealed-secrets controller, Kyverno, Karpenter, AWS LB Controller) are created at runtime by their Helm charts and documented by category -- they follow standard patterns for their respective tools and are not in git-managed manifests.

### system:masters Assessment

No custom system:masters bindings exist in git-managed manifests. EKS access entries use AmazonEKSClusterAdminPolicy (EKS-native access API, not system:masters group binding). Flux uses the cluster-admin ClusterRole via a ClusterRoleBinding (not the system:masters group). This satisfies IAM-01 requirements.

## IRSA Custom Policy Review (IAM-02)

All IRSA roles use OIDC trust conditions with StringEquals on `:sub` and `:aud` claims, scoping role assumption to specific Kubernetes service accounts only. Verified in `terraform-infra/root/dev/iam-roles/main.tf`.

| IRSA Role | Policy File | Service Account | Assessment | Flags |
|-----------|-------------|-----------------|------------|-------|
| karpenter_irsa_role | karpenter_policy.json | karpenter:karpenter | Well-scoped. EC2 launch/fleet ops, IAM PassRole scoped to specific ARN (eks_worker_nodes_role), EKS DescribeCluster on specific cluster (projectx), SQS scoped to specific queue (projectx-karpenter), SSM for AMI lookup | iam:CreateInstanceProfile on Resource:"*" -- required by Karpenter for dynamic instance profile management (instance profile names are generated at runtime) |
| velero-role | velero_policy.json | velero:velero-server | Well-scoped. S3 scoped to specific bucket (372517046622-velero-backups-dev). EC2 snapshot describe/create/delete actions require Resource:"*" per AWS API constraints | None |
| aws-lb-controller-role | aws_lb_controller_policy.json | kube-system:aws-load-balancer-controller | Matches official AWS-recommended policy. Mutating ELB/SG operations conditioned on elbv2.k8s.aws/cluster tag. IAM CreateServiceLinkedRole conditioned on ELB service name | waf-regional:* and shield:* actions included but unused -- standard canonical inclusion in AWS official policy |
| thanos-role | thanos_policy.json | monitoring:thanos-storegateway, thanos-compactor, kube-prometheus-stack-prometheus | Minimal. Only S3 ops (Get/Put/Delete/List) scoped to specific bucket (372517046622-thanos-dev) | None |
| ebs-csi-irsa-role | AmazonEBSCSIDriverPolicy (AWS-managed) | kube-system:ebs-csi-controller-sa | Skipped per D-10 -- AWS-managed policy, already scoped by AWS | N/A |

**Finding per D-11:** No overprivileged IRSA policies found that require modification. All custom policies are well-scoped with resource ARN constraints where applicable. Flagged items (Karpenter instance profiles, LB Controller WAF/Shield) are standard requirements or canonical inclusions -- document only, no changes needed.

## EKS Access Entries (IAM-01)

All access entries defined in `terraform-infra/eks-cluster/access-entries.tf`:

| Principal | Type | Policy | Justification |
|-----------|------|--------|---------------|
| altoha (IAM user) | STANDARD | AmazonEKSClusterAdminPolicy (cluster scope) | Solo project admin, break-glass access (D-07). Single human operator for learning project |
| GithubActionsTerraformDeploy (IAM role) | STANDARD | AmazonEKSClusterAdminPolicy (cluster scope) | CI/CD Terraform apply needs cluster-admin for EKS addons, access entries, and Flux bootstrap operations (D-06) |
| eks_worker_nodes_role | EC2_LINUX | None (node auth only) | Standard EKS node authentication entry. No additional policy -- node permissions come from instance profile IAM role |

**Backup per D-08:** Terraform state serves as the access entry backup -- all entries are fully defined in `terraform-infra/eks-cluster/access-entries.tf` and managed declaratively. No manual console entries exist.

## Decisions Made
- No IRSA policy changes needed -- all 4 custom policies confirmed as well-scoped with resource ARN constraints
- Karpenter iam:CreateInstanceProfile on Resource:* accepted as required (instance profiles are dynamically named)
- AWS LB Controller waf-regional/shield permissions accepted as canonical official policy inclusion
- No system:masters remediation needed -- no such bindings exist in git

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- IAM-01 (RBAC least-privilege audit) satisfied: all ClusterRoleBindings documented, no system:masters abuse
- IAM-02 (IRSA verification) satisfied: all custom policies verified as minimal, OIDC conditions confirmed
- Phase 7 complete -- ready for Phase 8 (CI/CD & GitOps security)

## Self-Check: PASSED

- FOUND: platform-tools/sealed-secrets/base/RBAC.yaml
- FOUND: .planning/phases/07-iam-rbac-hardening/07-02-SUMMARY.md
- FOUND: Task 1 commit 64549a5

---
*Phase: 07-iam-rbac-hardening*
*Completed: 2026-03-29*
