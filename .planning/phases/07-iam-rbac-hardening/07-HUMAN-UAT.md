---
status: partial
phase: 07-iam-rbac-hardening
source: [07-VERIFICATION.md]
started: 2026-03-29T18:31:00Z
updated: 2026-03-29T18:31:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Apply Terraform iam-roles workspace and confirm worker node IAM role
expected: Three overprivileged policies (AmazonEC2FullAccess, ElasticLoadBalancingFullAccess, AmazonEC2ContainerRegistryPowerUser) are no longer attached; only 2 managed policies + 1 custom policy remain
result: [pending]

### 2. Run kubectl get clusterrolebindings and confirm no system:masters
expected: Only cluster-reconciler-flux-system, crd-controller-flux-system, and sealed-secrets-reader-binding appear as custom CRBs; no system:masters group binding exists
result: [pending]

### 3. Confirm EKS nodes still join cluster after IAM change
expected: All worker nodes report Ready status; no CNI or registry pull failures
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
