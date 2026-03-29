---
phase: 06-kyverno-policy-engine
plan: 01
subsystem: infra
tags: [kyverno, pod-security-standards, admission-controller, flux, gitops, policy-as-code]

# Dependency graph
requires:
  - phase: 04-workload-hardening
    provides: "Security contexts (runAsNonRoot, drop ALL, readOnlyRootFilesystem) on all workloads"
  - phase: 03-network-security
    provides: "NetworkPolicy deny-default pattern for platform tools"
provides:
  - "Kyverno admission controller deployed via Flux GitOps"
  - "PSS Restricted ClusterPolicy in audit mode across all namespaces"
  - "PolicyReport-based audit trail for pod security compliance"
  - "Deny-default NetworkPolicy for Kyverno admission controller"
affects: [07-iam-rbac, 08-advanced-policies]

# Tech tracking
tech-stack:
  added: [kyverno, kyverno-helm-chart-3.x, clusterpolicy-crd, policyreport-crd]
  patterns: [built-in-podSecurity-subrule, audit-before-enforce, background-scanning]

key-files:
  created:
    - platform-tools/kyverno/base/namespace.yaml
    - platform-tools/kyverno/base/helmrepository.yaml
    - platform-tools/kyverno/base/helmrelease.yaml
    - platform-tools/kyverno/base/networkpolicy.yaml
    - platform-tools/kyverno/base/clusterpolicy-pss-restricted.yaml
    - platform-tools/kyverno/base/kustomization.yaml
    - platform-tools/kyverno/overlays/dev/kustomization.yaml
    - platform-tools/kyverno/overlays/dev/patch.yaml
    - clusters/dev-projectx/kyverno.yaml
  modified: []

key-decisions:
  - "Used built-in podSecurity subrule instead of kyverno-policies chart for simplicity"
  - "UID 65534 (nobody) for Kyverno containers matching upstream defaults, not 1001 like sealed-secrets"
  - "No namespace exclusions on ClusterPolicy -- all namespaces audited including kube-system"

patterns-established:
  - "Pattern: Single ClusterPolicy with podSecurity subrule covers entire PSS Restricted profile"
  - "Pattern: Kyverno base/overlay structure mirrors sealed-secrets reference pattern"

requirements-completed: [EKS-02, POL-01, POL-02]

# Metrics
duration: 1min
completed: 2026-03-29
---

# Phase 6 Plan 1: Kyverno Policy Engine Summary

**Kyverno admission controller with PSS Restricted audit policy deployed via Flux GitOps using built-in podSecurity subrule**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-29T17:02:17Z
- **Completed:** 2026-03-29T17:03:30Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Kyverno engine deployment with 2 replicas, PDB, security contexts (UID 65534), and monitoring via HelmRelease
- PSS Restricted ClusterPolicy using built-in podSecurity subrule in audit mode with background scanning across all namespaces
- Deny-default NetworkPolicy with explicit allows for webhook (9443), metrics (8000), DNS (53), and API server (443/6443)
- Dev overlay reducing resources to single replica with PDB and ServiceMonitor disabled
- Complete Flux GitOps chain from clusters/dev-projectx/kyverno.yaml through overlay to base

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Kyverno base manifests** - `f029ca9` (feat)
2. **Task 2: Create dev overlay and Flux Kustomization** - `d98ca37` (feat)

## Files Created/Modified
- `platform-tools/kyverno/base/namespace.yaml` - Kyverno namespace with PSS restricted labels
- `platform-tools/kyverno/base/helmrepository.yaml` - Kyverno Helm chart source
- `platform-tools/kyverno/base/helmrelease.yaml` - Kyverno engine with HA, PDB, security contexts, monitoring
- `platform-tools/kyverno/base/networkpolicy.yaml` - Deny-default + webhook/metrics/DNS/API allows
- `platform-tools/kyverno/base/clusterpolicy-pss-restricted.yaml` - PSS Restricted audit policy
- `platform-tools/kyverno/base/kustomization.yaml` - Base resource listing
- `platform-tools/kyverno/overlays/dev/kustomization.yaml` - Dev overlay referencing base
- `platform-tools/kyverno/overlays/dev/patch.yaml` - Dev resource reductions
- `clusters/dev-projectx/kyverno.yaml` - Flux Kustomization for GitOps reconciliation

## Decisions Made
- Used built-in podSecurity subrule instead of kyverno-policies Helm chart -- single 20-line ClusterPolicy covers entire PSS Restricted profile
- UID 65534 (nobody) for Kyverno containers matching upstream chart defaults, not UID 1001 used by sealed-secrets
- No namespace exclusions on ClusterPolicy -- all namespaces including kube-system audited per D-03; AWS-managed pod violations documented as known/expected per D-04

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required. Manifests are committed to Git; Flux will reconcile automatically on push to main.

## Known Stubs
None - all manifests are complete with production-ready values.

## Next Phase Readiness
- Kyverno manifests ready for Flux reconciliation once pushed to main
- PolicyReports will be generated after Kyverno deploys and background scan completes
- AWS-managed pods in kube-system (CoreDNS, kube-proxy) will show expected violations in PolicyReports
- Ready for Phase 7 (IAM/RBAC) or Phase 8 (advanced policies)

## Self-Check: PASSED

All 9 created files verified on disk. Both task commits (f029ca9, d98ca37) verified in git log.

---
*Phase: 06-kyverno-policy-engine*
*Completed: 2026-03-29*
