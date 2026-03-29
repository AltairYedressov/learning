# ProjectX Infrastructure Security Audit

## What This Is

A full security audit and hardening of the ProjectX AWS EKS platform — covering network/VPC, EKS & Kubernetes, IAM & access, and CI/CD & GitOps. The goal is production-ready infrastructure with all critical vulnerabilities identified and remediated collaboratively.

## Core Value

Every layer of the infrastructure follows security best practices, with no critical or high-severity vulnerabilities remaining.

## Requirements

### Validated

- ✓ AWS EKS cluster provisioned via Terraform — existing
- ✓ GitOps with Flux CD v2 — existing
- ✓ CI/CD via GitHub Actions with OIDC auth — existing
- ✓ Istio service mesh with mTLS — existing
- ✓ Platform tools deployed (Karpenter, Velero, EFK, Sealed Secrets) — existing
- ✓ Multi-environment support (dev/prod) — existing

### Active

- [ ] Network & VPC hardened (security groups, NACLs, routing, ingress/egress reviewed)
- [ ] EKS cluster security hardened (RBAC, pod security, secrets, API server access)
- [ ] IAM policies follow least privilege (roles, service accounts, IRSA)
- [ ] CI/CD pipeline secured (Flux config, image scanning, supply chain)
- [ ] Application-level vulnerabilities fixed (CORS, rate limiting, input validation)
- [ ] Kubernetes workload security (resource limits, security contexts, network policies)

### Out of Scope

- Moving nodes to private subnets — explicit user decision to keep nodes in public subnets
- Application feature development — audit and harden only, no new features
- Database/RDS security — no RDS currently in active use
- Cost optimization — separate concern from security

## Context

- Brownfield project: existing AWS EKS infrastructure managed by Terraform + Flux CD
- Portfolio/learning project for DevOps/Platform Engineering practices
- Known concerns from codebase analysis: CORS wildcard, no rate limiting, no input validation, hardcoded AWS account IDs, no API authentication
- Nodes intentionally kept in public subnets (user constraint)
- Environments: dev, prod (test is ephemeral for CI)

## Constraints

- **Architecture**: Nodes must remain in public subnets — user decision
- **Approach**: Collaborative fixing — each finding discussed before remediation
- **Tooling**: All changes via Terraform (infra) or GitOps manifests (platform/app) — no manual AWS console changes
- **Outcome**: Production-ready hardened infrastructure

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Keep nodes in public subnets | User preference — simplicity for learning project | — Pending |
| Collaborative fixing approach | User wants to evaluate each finding before applying fixes | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-28 after initialization*
