# ProjectX Portfolio v2 Deployment

## What This Is

A production deployment of the redesigned personal portfolio site at `yedressov.com` — a static Express-served frontend plus a Flask SMTP relay backend for contact-form submissions. Replaces the previous FastAPI/EJS portfolio that currently serves the domain. Runs on the existing AWS EKS platform behind Istio ingress.

## Core Value

**The contact form works end-to-end in production.** A visitor can submit the form and the message lands in the owner's inbox. Everything else (styling, static content) can be iterated on; this is the one path that must ship working.

## Requirements

### Validated

<!-- Existing capabilities of the platform, inherited from prior milestones -->

- ✓ EKS cluster on AWS with Istio service mesh — existing
- ✓ FluxCD GitOps reconciliation from this repo — existing
- ✓ AWS NLB + ACM TLS termination at `yedressov.com` — existing
- ✓ ECR registry for container images — existing
- ✓ Sealed Secrets controller in-cluster for encrypted-at-rest secrets — existing
- ✓ GitHub Actions CI with OIDC auth to AWS — existing
- ✓ Karpenter node autoscaling, EFK logs, Prometheus/Thanos metrics — existing
- ✓ Security baseline from prior audit: CORS restriction, rate limiting, body size limits, least-privilege IAM, Kyverno PSS, sealed-secrets RBAC hardening — existing

### Active

<!-- This milestone's hypotheses — shipped = validated, invalidated = out of scope -->

- [ ] New frontend container built from `app/portfolio/frontend/` (Express + helmet + compression + http-proxy-middleware, serving static HTML/CSS/JS)
- [ ] New backend container built from `app/portfolio/backend/` (Flask + gunicorn, contact-form SMTP relay)
- [ ] Dockerfiles for both services, pushed to ECR via existing CI pipeline
- [ ] Sealed Secret for Gmail SMTP credentials (SMTP_USER, SMTP_PASS, RECIPIENT_EMAIL) committed to Git
- [ ] Helm chart and/or Kustomize overlays updated to deploy new images (replacing old frontend/backend)
- [ ] Istio VirtualService routes `/api/contact` → new Flask backend, everything else → new Express frontend
- [ ] Environment config wired: `ALLOWED_ORIGINS`, `RATE_LIMIT`, `RATE_WINDOW_MINUTES`, SMTP env vars
- [ ] Old `app/backend/` (FastAPI) and `app/frontend/` (EJS) retired from chart/manifests
- [ ] Security baseline from prior audit preserved: CORS origins restricted to `yedressov.com`, rate limiting active on contact endpoint, body size capped
- [ ] Contact form smoke test in production: submit form → email delivered to `contact@yedressov.com`

### Out of Scope

- **Paid SMTP providers (SES, SendGrid, Mailgun)** — contact form must be free; Gmail SMTP (100/day) is sufficient for a portfolio
- **Persistent database for contact submissions** — emails are the audit trail; no DB writes
- **Blue/green or canary rollout** — user chose hard cutover; downtime window is acceptable for a portfolio
- **Multi-environment (prod cluster separate from dev)** — dev-projectx is the only cluster; single environment
- **Frontend build pipeline (bundlers, TS, frameworks)** — frontend is static HTML/CSS/vanilla JS by design
- **External Secrets Operator** — Sealed Secrets already installed; no new platform tool needed
- **Authentication/authorization on the site** — public portfolio, no login
- **WAF in front of NLB** — deferred; not required for a personal portfolio at this scale
- **reCAPTCHA or similar bot protection on contact form** — rely on rate limiting + body size limits from baseline security work. Revisit if spam becomes an issue.

## Context

### Inherited platform (from prior milestones)

The ProjectX platform is a full AWS EKS stack provisioned by Terraform and managed via FluxCD GitOps. A recent security audit (phases 01–07 on `feature/portfolio-networking`, now merged to `main`) hardened network policies, pod security, CI/CD, application security (on the old FastAPI backend), Kyverno policies, and IAM/RBAC. That audit's planning artifacts have been cleared; the hardening commits remain in history.

### Why the rewrite

The previous portfolio served a hardcoded résumé JSON from a FastAPI backend through an EJS template frontend. The new version reshapes the surface:
- Backend role shifts from **"serve résumé data"** to **"relay contact messages"** (Flask + SMTP).
- Frontend moves from server-rendered EJS to static HTML/CSS/JS served by Express with a small proxy middleware for `/api` calls.
- The résumé content is now baked into static HTML; no runtime data fetch.

### Codebase reference

See `.planning/codebase/` for the full map of stack, architecture, conventions, integrations, testing, and concerns (generated from the current `main` working tree).

### Key paths
- `app/portfolio/frontend/server.js` — new Express server (proxy + static)
- `app/portfolio/frontend/public/` — new static assets (HTML/CSS/JS)
- `app/portfolio/backend/app.py` — new Flask contact-form API
- `HelmCharts/portfolio/` — current Helm chart (targets old images — needs update)
- `clusters/dev-projectx/portfolio.yaml` — Flux Kustomization for the app
- `portfolio/base/` — Kustomize base with HelmRelease + VirtualService
- `terraform-infra/root/dev/ecr/` — ECR registry (existing)

## Constraints

- **Cost**: Contact form must be free — Gmail SMTP only; no paid email providers.
- **Architecture**: Nodes must remain in public subnets (carried from original platform constraint).
- **Tooling**: All changes via Terraform (infra) or GitOps manifests (platform/app) — no manual AWS console changes.
- **GitOps**: FluxCD reconciles from `main`; deployment happens by merge, not by `kubectl`.
- **Secrets**: Gmail credentials must be encrypted before commit — Sealed Secrets only, no plain K8s Secrets in Git.
- **Security baseline**: Preserve hardening from the prior audit — CORS locked to `yedressov.com`, rate limiting, body size caps, least-privilege IAM, Kyverno PSS audit.
- **Branch**: Work directly on `main` per user direction (note: local `main` has diverged from `origin/main` by 84 commits; resolution deferred).
- **Downtime**: Hard cutover is acceptable; no zero-downtime requirement for this milestone.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Hard cutover instead of blue/green | Portfolio site; brief downtime is acceptable; simplest path | — Pending |
| Gmail SMTP over SES/SendGrid | User requires free tier; 100/day is more than enough | — Pending |
| Sealed Secrets for SMTP creds | Matches existing GitOps pattern; no new operator needed | — Pending |
| Work directly on `main` | User directive; planning artifacts live with the code | — Pending |
| Retire old FastAPI/EJS app entirely | New backend has a different purpose (SMTP relay, not résumé API); no value keeping both | — Pending |
| Static frontend (no bundler/framework) | Simplicity; no build step; matches current `app/portfolio/frontend/public/` | — Pending |
| No CAPTCHA on contact form (initial) | Rate limit + body size cap from audit baseline are sufficient for expected traffic | ⚠️ Revisit if spam appears |

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
