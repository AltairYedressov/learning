---
phase: 03-network-security
plan: 04
subsystem: infra
tags: [kubernetes, networkpolicy, karpenter, prometheus, coredns, kube-system, gitops]

# Dependency graph
requires:
  - phase: 03-02
    provides: "Portfolio and Istio namespace NetworkPolicies, PeerAuthentication patterns"
provides:
  - "Default-deny NetworkPolicies for karpenter, monitoring, and kube-system namespaces"
  - "kube-system GitOps delivery path via Flux Kustomization"
  - "Complete namespace network isolation across all cluster namespaces (NET-01)"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: ["Multi-document YAML for kube-system CoreDNS and kube-proxy policies", "Open ingress on CoreDNS port 53 (no from selector) for cluster-wide DNS"]

key-files:
  created:
    - platform-tools/karpenter/base/networkpolicy.yaml
    - platform-tools/eks-monitoring/base/networkpolicy.yaml
    - platform-tools/kube-system/base/networkpolicy.yaml
    - platform-tools/kube-system/base/kustomization.yaml
    - clusters/dev-projectx/kube-system.yaml
  modified:
    - platform-tools/karpenter/base/kustomization.yaml
    - platform-tools/eks-monitoring/base/kustomization.yaml

key-decisions:
  - "CoreDNS ingress port 53 has no from selector to ensure all namespaces can resolve DNS"
  - "kube-system deployed last per Pitfall 2 to minimize DNS disruption risk"

patterns-established:
  - "kube-system policies target specific pods (kube-dns, kube-proxy) rather than podSelector: {}"

requirements-completed: [NET-01]

# Metrics
duration: 1min
completed: 2026-03-29
---

# Phase 03 Plan 04: Remaining Namespace NetworkPolicies Summary

**Default-deny NetworkPolicies for karpenter, monitoring, and kube-system with explicit allow-lists completing NET-01 cluster-wide network isolation**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-29T12:05:02Z
- **Completed:** 2026-03-29T12:06:07Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- Created default-deny NetworkPolicies for karpenter (AWS API + webhook egress), monitoring (scraping + istiod egress), and kube-system (CoreDNS + kube-proxy)
- Wired all policies into Kustomization resources for GitOps delivery
- Created kube-system Flux Kustomization for automated deployment
- Completed NET-01: all cluster namespaces now have default-deny with explicit allow-lists

## Task Commits

Each task was committed atomically:

1. **Task 1: Create NetworkPolicies for karpenter, monitoring, and kube-system** - `8f0a57b` (feat)
2. **Task 2: Wire NetworkPolicies into Kustomization files and create kube-system GitOps delivery** - `1e4fe8a` (chore)

## Files Created/Modified
- `platform-tools/karpenter/base/networkpolicy.yaml` - Karpenter default-deny with AWS API, webhook, DNS egress
- `platform-tools/eks-monitoring/base/networkpolicy.yaml` - Monitoring default-deny with scraping ports, istiod xDS, Grafana ingress
- `platform-tools/kube-system/base/networkpolicy.yaml` - CoreDNS (open port 53 ingress) and kube-proxy policies
- `platform-tools/karpenter/base/kustomization.yaml` - Added networkpolicy.yaml reference
- `platform-tools/eks-monitoring/base/kustomization.yaml` - Added networkpolicy.yaml reference
- `platform-tools/kube-system/base/kustomization.yaml` - New kustomization for kube-system base
- `clusters/dev-projectx/kube-system.yaml` - Flux Kustomization for kube-system policy delivery

## Decisions Made
- CoreDNS ingress on port 53 uses no `from:` selector to ensure cluster-wide DNS reachability
- kube-system policies target specific pod labels (k8s-app: kube-dns, k8s-app: kube-proxy) rather than blanket podSelector: {}
- kube-system deployed last per Pitfall 2 to minimize DNS disruption risk

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- NET-01 fully addressed: all namespaces (portfolio, istio-system, istio-ingress, sealed-secrets, flux-system, karpenter, monitoring, kube-system) have default-deny NetworkPolicies
- Combined with Plans 02 and 03, cluster-wide network isolation is complete
- Ready for Phase 04+ security hardening work

## Self-Check: PASSED

All 7 files verified present. Both task commits (8f0a57b, 1e4fe8a) confirmed in git log.

---
*Phase: 03-network-security*
*Completed: 2026-03-29*
