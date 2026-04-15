---
phase: 3
name: Chart, GitOps Deploy & Old-App Retirement
status: ready-for-planning
---

# Phase 3: Chart, GitOps Deploy & Old-App Retirement — Context

**Gathered:** 2026-04-15
**Mode:** Interactive (autonomous --interactive)

<domain>
## Phase Boundary

1. Update the existing `HelmCharts/portfolio/` chart so it deploys the NEW
   `portfolio-web` + `portfolio-api` images from Phase 2's ECR repos with
   sealed SMTP credentials mounted via `envFrom.secretRef`.
2. Publish the updated chart to `oci://...ecr.../helm-charts/` via CI so
   Flux picks it up.
3. Align the VirtualService and resource wiring so Istio routes `/api/*` to
   `portfolio-api:5000` and everything else to `portfolio-web:3000`.
4. Flip `clusters/dev-projectx/portfolio.yaml` (already present) to consume
   the new chart version. Remove old-app Deployments/Services from the
   chart. Delete `app/backend/` and `app/frontend/` source trees.

Out of scope: live traffic verification + real email send test (Phase 4).

</domain>

<decisions>
## Implementation Decisions (Locked)

### D-01 — Backend port: 5000 (not 8000)
- Chart `values.yaml` `ports.api` = 5000. Previously 8000 — reconciled.
- Matches Phase 1 Dockerfile `EXPOSE 5000`, `BACKEND_PORT` default, all
  verification already passed locally.
- All probes, Service, NetworkPolicy, VirtualService updated accordingly.

### D-02 — Container names and image refs
- Chart values:
  - `images.web` = `${ECR}/portfolio-web:<sha>` (was `portfolio-frontend`)
  - `images.api` = `${ECR}/portfolio-api:<sha>` (was `portfolio-backend`)
- Rename chart value keys: `frontend` → `web`, `api` stays.
- Rename image-automation annotations to match (see Phase 2 D-04).
- Update `portfolio/base/helmrelease.yaml` values block to new keys.

### D-03 — Probe paths
- Backend liveness/readiness: `GET /health` (bare path added in Phase 1).
  Keep existing `/api/health` reachable but probes use `/health` for
  consistency with frontend.
- Frontend liveness/readiness: `GET /health` (added in Phase 1 — does NOT
  proxy to backend).

### D-04 — Sealed secret mount
- `envFrom: - secretRef: { name: portfolio-smtp }` on the API container.
- Depends on the `portfolio-smtp` K8s Secret materialized by the Sealed
  Secrets controller from `templates/sealed-secret.yaml` (Phase 2).
- Backend container also gets explicit env for non-secret config
  (`ALLOWED_ORIGINS`, `RATE_LIMIT`, `RATE_WINDOW_MINUTES`,
  `MAX_BODY_BYTES`, `BACKEND_PORT`) via `env:` entries with values
  from `values.yaml`.
- Frontend container env: `PORT=3000`, `BACKEND_URL=http://portfolio-api.portfolio.svc.cluster.local:5000`,
  `NODE_ENV=production`.

### D-05 — CORS locked to prod + dev
- `ALLOWED_ORIGINS` value: `https://yedressov.com,http://localhost:3000`.
- Backend code already reads this env and feeds it to Flask-CORS.

### D-06 — Chart publication workflow
- Extend `.github/workflows/portfolio-images.yaml` OR add a new
  `.github/workflows/portfolio-chart.yaml`:
  - Trigger: push to `main` with path filter `HelmCharts/portfolio/**`.
  - Steps: `helm lint`, bump chart version
    (use Chart.yaml version or commit sha suffix),
    `helm package`, `helm push oci://${ECR}/helm-charts/`.
  - Same OIDC role + `aws-actions/amazon-ecr-login@v2`.
- Planner picks "extend existing workflow" vs "new file" based on CI
  concurrency group needs. Either is acceptable.

### D-07 — Old-app retirement
- `git rm -r app/backend app/frontend` — delete old FastAPI/EJS source.
- Chart's existing Deployment/Service templates already target
  `portfolio-api` / `portfolio-frontend`; rename frontend resources
  to `portfolio-web` for consistency with the new image name and
  value-key rename.
- Update `portfolio/base/networkpolicy.yaml` label selectors accordingly
  (`app: portfolio-frontend` → `app: portfolio-web`).
- VirtualService `destination.host` → `portfolio-web` (was
  `portfolio-frontend`) and `portfolio-api` stays.
- Any ECR lifecycle cleanup for old `images/portfolio-backend` +
  `images/portfolio-frontend` is deferred — those repos are under a
  different path (`images/...`) and won't interfere; can be cleaned
  up manually.

### D-08 — Istio AuthorizationPolicy (backend ingress lock-down)
- Add an AuthorizationPolicy in `portfolio/base/authorizationpolicy.yaml`
  that allows traffic to `portfolio-api` ONLY from:
  1. The frontend service account (or `app: portfolio-web` pods via
     Istio principals: `cluster.local/ns/portfolio/sa/portfolio-web`)
  2. The ingress gateway (`cluster.local/ns/istio-ingress/sa/istio-ingressgateway-service-account`)
- This reinforces the existing NetworkPolicy with mesh-level mTLS
  identity checks, satisfying SEC-03 / DEP-03.

### D-09 — Resource limits
- Keep existing: api + web both 100m/250m cpu, 128Mi/256Mi memory.
- If Phase 4 observability flags pressure we revisit; do NOT bump
  preemptively.

### D-10 — ServiceAccounts
- Create two dedicated ServiceAccounts (`portfolio-web`,
  `portfolio-api`) in the chart so Istio mTLS principals in D-08 work.
- No IRSA annotations needed (no AWS API calls from pods).

### D-11 — Chart version bump
- `Chart.yaml` version bumped on every meaningful change. The CI
  chart-push workflow refuses to re-push an existing immutable version.
- `appVersion` mirrors the application commit SHA.

### D-12 — What Phase 3 does NOT do
- No real SMTP send test — Phase 4.
- No DNS/TLS certificate changes — already live from previous milestones.
- No new platform tools installed — Flux and Sealed Secrets already there.

</decisions>

<code_context>
## Existing Code Insights (verified)

- `HelmCharts/portfolio/templates/01-backend.yaml` already has a strong
  `securityContext` (non-root, readOnlyRootFilesystem, drop ALL caps,
  seccomp RuntimeDefault) — keep, just switch port 8000→5000 and probe
  path to `/health`.
- `HelmCharts/portfolio/templates/02-frontend.yaml` assumed similar.
- `portfolio/base/networkpolicy.yaml` already has default-deny +
  narrow ingress/egress. Update `app: portfolio-frontend` → `portfolio-web`
  and backend port 8000 → 5000.
- `portfolio/base/virtualservice.yaml` already routes /api → backend
  and / → frontend. Update `host:` + port to new names/5000.
- `portfolio/base/helmrelease.yaml` currently has inline values
  pointing at OLD image repos (`images/portfolio-backend:5e83c60`).
  Update to new `portfolio-web` / `portfolio-api` from Phase 2 (these
  are rewritten automatically by image-automation once it's live, but
  the chart default should also be sane).
- Phase 2 committed `HelmCharts/portfolio/templates/sealed-secret.yaml`
  with placeholder ciphertext. Phase 3 only consumes; user runs
  kubeseal separately.

</code_context>

<specifics>
## Specific Ideas

- The chart's values.yaml does not currently exist as a file
  (values live inline in HelmRelease). Create a real
  `HelmCharts/portfolio/values.yaml` with sensible defaults so
  `helm lint` / `helm template` stops failing on nil refs (Phase 2
  VERIFICATION noted this). The HelmRelease values block still wins
  via override.
- Annotate image-automation-watched lines:
  ```yaml
  images:
    web: 372517046622.dkr.ecr.us-east-1.amazonaws.com/portfolio-web:PLACEHOLDER # {"$imagepolicy": "flux-system:portfolio-web"}
    api: 372517046622.dkr.ecr.us-east-1.amazonaws.com/portfolio-api:PLACEHOLDER # {"$imagepolicy": "flux-system:portfolio-api"}
  ```
- Bump `portfolio/base/helmrelease.yaml` spec.chart.spec.version to a
  version the chart-publish workflow has actually uploaded (planner may
  decide to omit version pin and let the HelmRelease grab latest by
  semver range).

</specifics>

<deferred>
## Deferred Ideas

- Deleting old `images/portfolio-backend` + `images/portfolio-frontend`
  ECR repos — manual cleanup once Phase 4 confirms prod stability.
- HPA / PDB for the new workloads — traffic volume is tiny; add only if
  observability flags it.
- External Secrets Operator instead of Sealed Secrets — unchanged, not
  planned for this milestone.
- Multi-environment overlays (prod vs dev) for the chart — current
  cluster is dev-only.

</deferred>

<canonical_refs>
## Canonical References

- `.planning/ROADMAP.md` — Phase 3 goal + success criteria
- `.planning/REQUIREMENTS.md` — DEP-01..05, SEC-01, SEC-03, SEC-04, SEC-06
- `.planning/phases/01-package-local-verify/01-CONTEXT.md` — port 5000
- `.planning/phases/02-secrets-ci-image-push/02-CONTEXT.md` — ECR repos,
  image-automation, sealed-secret path
- `HelmCharts/portfolio/Chart.yaml`
- `HelmCharts/portfolio/templates/01-backend.yaml`
- `HelmCharts/portfolio/templates/02-frontend.yaml`
- `HelmCharts/portfolio/templates/sealed-secret.yaml`
- `portfolio/base/helmrelease.yaml`
- `portfolio/base/virtualservice.yaml`
- `portfolio/base/networkpolicy.yaml`
- `clusters/dev-projectx/portfolio.yaml` — Flux Kustomization
- `platform-tools/istio/istio-ingress/base/gateway.yaml` — existing gateway

</canonical_refs>
