---
phase: 03-network-security
plan: 03
subsystem: infra
tags: [networkpolicy, kubernetes, istio, flux, network-isolation, default-deny]

# Dependency graph
requires:
  - phase: 03-02
    provides: "Portfolio NetworkPolicy pattern and PeerAuthentication for mTLS"
provides:
  - "Default-deny NetworkPolicies for istio-ingress, istio-system, and flux-system namespaces"
  - "Complete network isolation for all Istio and GitOps infrastructure namespaces"
affects: [03-04, phase-verification]

# Tech tracking
tech-stack:
  added: []
  patterns: ["default-deny NetworkPolicy with explicit allow-list for platform namespaces", "podSelector: {} for namespace-wide policies (flux-system)"]

key-files:
  created:
    - platform-tools/istio/istio-ingress/base/networkpolicy.yaml
    - platform-tools/istio/istio-system/base/networkpolicy.yaml
    - clusters/dev-projectx/flux-system/networkpolicy.yaml
  modified:
    - platform-tools/istio/istio-ingress/base/kustomization.yaml
    - platform-tools/istio/istio-system/base/kustomization.yaml
    - clusters/dev-projectx/flux-system/kustomization.yaml

key-decisions:
  - "istiod xDS ingress (15012) and webhook ingress (15017) open from all sources -- any Istio-injected pod needs xDS and API server calls webhooks from any IP"
  - "flux-system uses podSelector: {} to cover all controllers uniformly (source, kustomize, helm, notification)"
  - "Flux HTTPS egress (443) open to all destinations -- fetches from GitHub, Helm repos, and OCI registries at various IPs"

patterns-established:
  - "Platform namespace NetworkPolicy: default-deny + DNS + kube-apiserver + service-specific ports"
  - "Namespace-wide policy via empty podSelector for uniform controller groups"

requirements-completed: [NET-01]

# Metrics
duration: 1min
completed: 2026-03-29
---

# Phase 03 Plan 03: Platform Namespace NetworkPolicies Summary

**Default-deny NetworkPolicies for istio-ingress, istio-system, and flux-system with explicit allow-lists for xDS, webhooks, GitHub egress, and kube-apiserver access**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-29T12:04:53Z
- **Completed:** 2026-03-29T12:05:42Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Created default-deny NetworkPolicy for istio-ingress gateway allowing NLB traffic (8080/8443), egress to portfolio pods, istiod xDS, DNS, and kube-apiserver
- Created default-deny NetworkPolicy for istiod allowing xDS (15012), webhook (15017), and Prometheus (15014) ingress, with DNS and kube-apiserver egress
- Created default-deny NetworkPolicy for Flux controllers allowing webhook ingress (9292), Prometheus scraping (8080), and egress to DNS, GitHub/HTTPS (443), kube-apiserver (6443), and SSH (22)
- Wired all 3 NetworkPolicies into their respective Kustomization resources for GitOps delivery

## Task Commits

Each task was committed atomically:

1. **Task 1: Create NetworkPolicies for istio-ingress, istio-system, and flux-system** - `de26db3` (feat)
2. **Task 2: Wire NetworkPolicies into Kustomization files** - `af9c5d7` (chore)

## Files Created/Modified
- `platform-tools/istio/istio-ingress/base/networkpolicy.yaml` - Ingress gateway network isolation (NLB ingress, portfolio egress, xDS, DNS, kube-apiserver)
- `platform-tools/istio/istio-system/base/networkpolicy.yaml` - istiod network isolation (xDS, webhooks, Prometheus ingress; DNS, kube-apiserver egress)
- `clusters/dev-projectx/flux-system/networkpolicy.yaml` - Flux controllers network isolation (webhooks, Prometheus ingress; DNS, HTTPS, kube-apiserver, SSH egress)
- `platform-tools/istio/istio-ingress/base/kustomization.yaml` - Added networkpolicy.yaml to resources
- `platform-tools/istio/istio-system/base/kustomization.yaml` - Added networkpolicy.yaml to resources
- `clusters/dev-projectx/flux-system/kustomization.yaml` - Added networkpolicy.yaml to resources

## Decisions Made
- istiod xDS ingress (15012) and webhook ingress (15017) left open from all sources since any Istio-injected pod needs xDS and the API server calls webhooks from any IP
- flux-system uses `podSelector: {}` to cover all controllers uniformly rather than per-controller policies
- Flux HTTPS egress (443) open to all destinations because it fetches from GitHub, Helm repos, and OCI registries at various IPs

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- istio-ingress, istio-system, and flux-system namespaces now have default-deny NetworkPolicies
- Combined with Plan 02 (portfolio namespace), all application and platform namespaces have network isolation
- Ready for Plan 04 (remaining platform tool namespaces) to complete full cluster network segmentation

---
*Phase: 03-network-security*
*Completed: 2026-03-29*
