---
phase: 07-iam-rbac-hardening
plan: 01
subsystem: infra
tags: [iam, aws, terraform, eks, least-privilege, worker-nodes]

# Dependency graph
requires:
  - phase: 01-security-baseline
    provides: CIS EKS baseline identifying overprivileged IAM roles
provides:
  - Least-privilege worker node IAM role (3 overprivileged policies removed)
  - Custom ec2:Describe* policy for node metadata lookups
affects: [07-02, ci-cd-pipeline]

# Tech tracking
tech-stack:
  added: []
  patterns: [custom-iam-policy-for-worker-nodes, least-privilege-managed-policies]

key-files:
  created:
    - terraform-infra/iam-role-module/Policies/eks_worker_node_policy.json
  modified:
    - terraform-infra/root/dev/iam-roles/variables.tf
    - terraform-infra/root/dev/iam-roles/main.tf

key-decisions:
  - "Removed AmazonEC2FullAccess, ElasticLoadBalancingFullAccess, AmazonEC2ContainerRegistryPowerUser from worker nodes"
  - "Custom policy scoped to ec2:DescribeInstances and ec2:DescribeTags only (CNI plugin covered by AmazonEKS_CNI_Policy)"

patterns-established:
  - "Worker node IAM: only AmazonEC2ContainerRegistryReadOnly + AmazonEKS_CNI_Policy managed, plus scoped custom policy"

requirements-completed: [IAM-03]

# Metrics
duration: 1min
completed: 2026-03-29
---

# Phase 7 Plan 1: Worker Node IAM Least-Privilege Summary

**Stripped 3 overprivileged AWS managed policies from EKS worker node IAM role, replaced with minimal ec2:Describe* custom policy**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-29T17:46:40Z
- **Completed:** 2026-03-29T17:47:29Z
- **Tasks:** 1
- **Files modified:** 3

## Accomplishments
- Removed AmazonEC2FullAccess, ElasticLoadBalancingFullAccess, and AmazonEC2ContainerRegistryPowerUser from worker node IAM role
- Created minimal custom IAM policy with only ec2:DescribeInstances and ec2:DescribeTags for node metadata lookups
- Wired custom_policy_json_path to eks_worker_nodes module following existing Karpenter pattern

## Task Commits

Each task was committed atomically:

1. **Task 1: Create custom worker node IAM policy and update Terraform configuration** - `6a7abe5` (feat)

## Files Created/Modified
- `terraform-infra/iam-role-module/Policies/eks_worker_node_policy.json` - Minimal custom IAM policy for worker node metadata lookups (ec2:DescribeInstances, ec2:DescribeTags)
- `terraform-infra/root/dev/iam-roles/variables.tf` - Trimmed worker node managed policy list from 5 to 2 ARNs, added description field
- `terraform-infra/root/dev/iam-roles/main.tf` - Added custom_policy_json_path to eks_worker_nodes module block

## Decisions Made
- Followed plan decisions D-01 through D-05 exactly as specified
- Resource: "*" required for ec2:Describe* actions (IAM does not support resource-level restrictions on these)
- CNI plugin's ec2:DescribeNetworkInterfaces already covered by retained AmazonEKS_CNI_Policy

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Pre-existing terraform fmt failure in `terraform-infra/root/dev/eks/main.tf` (unrelated to this plan). Our modified files pass fmt check. Logged as out-of-scope.

## User Setup Required

None - no external service configuration required. Changes take effect on next `terraform apply` for the iam-roles workspace.

## Next Phase Readiness
- Worker node IAM hardened, ready for Plan 07-02 (additional IAM/RBAC hardening)
- terraform apply required to deploy changes to AWS

---
*Phase: 07-iam-rbac-hardening*
*Completed: 2026-03-29*
