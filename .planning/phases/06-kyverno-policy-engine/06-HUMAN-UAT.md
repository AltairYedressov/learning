---
status: partial
phase: 06-kyverno-policy-engine
source: [06-VERIFICATION.md]
started: 2026-03-29T18:01:00Z
updated: 2026-03-29T18:01:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. PolicyReports show zero violations on pre-hardened workloads
expected: After Flux reconciles, `kubectl get policyreport -A` shows 0 FAIL entries in portfolio, monitoring, istio-system, flux-system, karpenter, sealed-secrets, and velero namespaces. AWS-managed kube-system pods (CoreDNS, kube-proxy) may show violations — documented as known/expected per D-04.
result: [pending]

### 2. Test deployment violating PSS Restricted is caught by Kyverno in audit mode
expected: Apply a privileged pod to default namespace. Pod is admitted (audit mode) but a PolicyReport entry with `result: fail` and `policy: pss-restricted-audit` appears within ~30s via `kubectl get policyreport -n default`.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
