---
status: partial
phase: 02-ci-cd-security-gate
source: [02-VERIFICATION.md]
started: 2026-03-28T00:00:00Z
updated: 2026-03-28T00:00:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. PR blocking behavior -- Trivy
expected: Open a PR against main modifying app/**. Trivy scan step shows findings table in GitHub Actions output; job exits non-zero on CRITICAL/HIGH fixable CVE; PR cannot be merged.
result: [pending]

### 2. PR blocking behavior -- Checkov
expected: Open a PR against main modifying terraform-infra/**. Checkov output visible in job log; job exits non-zero on findings; PR cannot be merged.
result: [pending]

### 3. Branch protection enforcement via Terraform
expected: After terraform apply on eks/ stack, GitHub Settings > Branches shows branch protection rule with publish-images and terraform (iam-roles) as required checks; PRs with failing checks are blocked.
result: [pending]

## Summary

total: 3
passed: 0
issues: 0
pending: 3
skipped: 0
blocked: 0

## Gaps
