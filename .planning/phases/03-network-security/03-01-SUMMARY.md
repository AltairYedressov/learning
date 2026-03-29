---
phase: 03-network-security
plan: 01
subsystem: infra
tags: [terraform, security-groups, egress, aws, vpc, eks]

# Dependency graph
requires: []
provides:
  - "Scoped egress rules on all 4 security groups (worker-nodes, cluster, ALB, database)"
  - "Reusable egress_rules variable in SG module matching ingress pattern"
affects: [03-network-security, terraform-infra]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Dynamic egress rules via for_each mirroring ingress pattern"]

key-files:
  created: []
  modified:
    - "terraform-infra/networking/security-group/variables.tf"
    - "terraform-infra/networking/security-group/security-group.tf"
    - "terraform-infra/root/dev/networking/main.tf"

key-decisions:
  - "Worker nodes keep HTTPS 443 to 0.0.0.0/0 for AWS API access (ECR, S3, STS)"
  - "DNS egress to 0.0.0.0/0 (not VPC CIDR) for external DNS resolution"
  - "Database SG uses implicit default (no egress_rules) rather than explicit empty list"

patterns-established:
  - "egress_rules variable mirrors rules variable structure for consistent SG module interface"

requirements-completed: [NET-02]

# Metrics
duration: 3min
completed: 2026-03-29
---

# Phase 3 Plan 1: SG Egress Scoping Summary

**Replaced wide-open 0.0.0.0/0 all-protocol egress with scoped per-SG egress rules via dynamic Terraform for_each**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-29T04:57:38Z
- **Completed:** 2026-03-29T05:00:38Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Extended SG module with egress_rules variable and dynamic resource, removing hardcoded wide-open egress
- Worker nodes SG scoped to HTTPS (443), DNS (53 UDP+TCP), and VPC-internal traffic
- Cluster SG scoped to kubelet (10250) within VPC CIDR only
- ALB SG scoped to NodePort range (30000-32767) and Istio ports (8080, 8443) within VPC CIDR
- Database SG has no explicit egress (stateful SG handles return traffic)

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend SG module with egress_rules variable and dynamic resource** - `affc0ef` (feat)
2. **Task 2: Pass scoped egress rules to each SG module call** - `37446df` (feat)

## Files Created/Modified
- `terraform-infra/networking/security-group/variables.tf` - Added egress_rules variable with same type as ingress rules
- `terraform-infra/networking/security-group/security-group.tf` - Replaced all_ipv4/all_ipv6 with dynamic egress for_each
- `terraform-infra/root/dev/networking/main.tf` - Added scoped egress_rules to worker-nodes-sg, cluster-sg, and alb-sg

## Decisions Made
- Worker nodes keep HTTPS 443 to 0.0.0.0/0 (not VPC CIDR) because they need to reach AWS APIs (ECR, S3, STS) which are outside the VPC
- DNS egress to 0.0.0.0/0 for external DNS resolution (not just VPC DNS)
- Database SG relies on Terraform default (empty list) rather than explicit `egress_rules = []` for cleaner HCL

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- All security groups now have scoped egress, ready for network policy work in subsequent plans
- terraform fmt passes on all modified directories

---
*Phase: 03-network-security*
*Completed: 2026-03-29*
