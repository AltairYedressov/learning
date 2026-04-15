---
name: ProjectX Portfolio Platform
created: 2026-04-15
---

# ProjectX Portfolio Platform

## What This Is

A personal portfolio web application running on AWS EKS — Node.js/Express frontend (EJS templates) + Python/FastAPI backend, deployed via Helm/FluxCD GitOps, fronted by Istio. Infrastructure provisioned via Terraform.

## Core Value

A production-grade, secure, continuously-deployed portfolio platform that serves as both a public-facing site and a reference implementation of cloud-native best practices.

## Context

Brownfield codebase. Initial use case for GSD tooling is iterative UI/UX features and a forthcoming security audit & hardening milestone. Codebase map lives in `.planning/codebase/`.

## Requirements

### Validated

- ✓ Frontend serves portfolio pages via EJS templates — existing
- ✓ Backend exposes resume data as REST JSON — existing
- ✓ GitOps deploys via FluxCD on 10m reconciliation — existing
- ✓ Istio routes traffic with automatic mTLS — existing
- ✓ Dark/light mode toggle on each page — existing

### Active

- [ ] Terminal typing ASMR sound synced to typewriter animation, with sound on/off toggle in top-right nav

### Out of Scope

- Multi-tenant / multi-user features — single-author portfolio
- Database-backed content — resume data is static

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Nodes stay in public subnets | User architecture choice | — Locked |
| All infra changes via Terraform or GitOps (no console) | Reproducibility / audit trail | — Locked |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-15 after initialization*
