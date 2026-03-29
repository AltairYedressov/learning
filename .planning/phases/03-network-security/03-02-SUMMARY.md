---
phase: 03-network-security
plan: 02
subsystem: infra
tags: [kubernetes, networkpolicy, istio, mtls, peerauthentication, security]

# Dependency graph
requires:
  - phase: 03-network-security
    provides: "Phase context with research on NetworkPolicy and mTLS patterns"
provides:
  - "Default-deny NetworkPolicies for portfolio-api and portfolio-frontend pods"
  - "Mesh-wide STRICT mTLS via Istio PeerAuthentication"
  - "PERMISSIVE mTLS override for monitoring namespace"
affects: [03-network-security, eks-monitoring, portfolio]

# Tech tracking
tech-stack:
  added: [NetworkPolicy, PeerAuthentication]
  patterns: [default-deny-networkpolicy, mesh-wide-strict-mtls, namespace-permissive-override]

key-files:
  created:
    - portfolio/base/networkpolicy.yaml
    - platform-tools/istio/istio-system/base/peerauthentication.yaml
    - platform-tools/eks-monitoring/base/peerauthentication.yaml
  modified:
    - portfolio/base/kustomization.yaml
    - platform-tools/istio/istio-system/base/kustomization.yaml
    - platform-tools/eks-monitoring/base/kustomization.yaml

key-decisions:
  - "Multi-document YAML for backend+frontend NetworkPolicies in single file (consistent with existing patterns)"
  - "Monitoring namespace gets PERMISSIVE override to prevent Prometheus scraping breakage"

patterns-established:
  - "Default-deny NetworkPolicy pattern: policyTypes [Ingress, Egress] with explicit allow-lists for each pod type"
  - "PeerAuthentication layering: STRICT mesh-wide in istio-system, PERMISSIVE overrides per namespace as needed"

requirements-completed: [NET-01, NET-03]

# Metrics
duration: 1min
completed: 2026-03-29
---

# Phase 3 Plan 2: Portfolio NetworkPolicies & mTLS Summary

**Default-deny NetworkPolicies for portfolio backend/frontend with mesh-wide STRICT mTLS and monitoring PERMISSIVE override**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-29T04:57:38Z
- **Completed:** 2026-03-29T04:58:39Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments
- Portfolio namespace now has default-deny NetworkPolicies for both backend (portfolio-api) and frontend (portfolio-frontend) pods with explicit ingress/egress allow-lists
- Mesh-wide STRICT mTLS enforcement via PeerAuthentication in istio-system namespace -- all plaintext connections rejected
- Monitoring namespace has PERMISSIVE PeerAuthentication override to prevent Prometheus scraping breakage when pods lack Istio sidecars
- All manifests wired into Kustomization resources for automatic GitOps delivery via Flux

## Task Commits

Each task was committed atomically:

1. **Task 1: Create portfolio NetworkPolicies and Istio PeerAuthentication manifests** - `f1f9580` (feat)
2. **Task 2: Wire manifests into Kustomization resources lists** - `90c3ebd` (chore)
3. **Task 3: Create PERMISSIVE PeerAuthentication override for monitoring namespace** - `745790e` (feat)

## Files Created/Modified
- `portfolio/base/networkpolicy.yaml` - Default-deny NetworkPolicies for portfolio-api (ingress from frontend/istio-ingress/monitoring; egress to DNS/kube-apiserver/istiod) and portfolio-frontend (ingress from istio-ingress/monitoring; egress to DNS/backend/istiod)
- `platform-tools/istio/istio-system/base/peerauthentication.yaml` - Mesh-wide STRICT mTLS PeerAuthentication
- `platform-tools/eks-monitoring/base/peerauthentication.yaml` - Namespace-scoped PERMISSIVE mTLS override for monitoring
- `portfolio/base/kustomization.yaml` - Added networkpolicy.yaml to resources
- `platform-tools/istio/istio-system/base/kustomization.yaml` - Added peerauthentication.yaml to resources
- `platform-tools/eks-monitoring/base/kustomization.yaml` - Added peerauthentication.yaml to resources

## Decisions Made
- Used multi-document YAML (--- separator) for backend+frontend NetworkPolicies in a single file, consistent with the sealed-secrets pattern
- Monitoring namespace gets PERMISSIVE override rather than workload-specific port exceptions, since Prometheus may not have an Istio sidecar at all

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required

None - no external service configuration required.

## Known Stubs

None - all manifests contain complete configurations with no placeholder values.

## Next Phase Readiness
- Portfolio namespace is now hardened with default-deny policies and mTLS
- Ready for remaining Phase 3 plans (additional namespace NetworkPolicies, security group hardening)
- Monitoring PERMISSIVE override ensures observability continues working under STRICT mTLS

---
*Phase: 03-network-security*
*Completed: 2026-03-29*
