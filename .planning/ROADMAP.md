# Roadmap — Portfolio v2 Deployment

**Milestone goal:** Ship the new Express+Flask portfolio to `yedressov.com` on the existing EKS/Istio/Flux platform, with a working contact form end-to-end.

**Granularity:** coarse (4 phases)
**Coverage:** 34/34 v1 requirements mapped
**Dependency spine:** Package → Secrets+CI push → Deploy+Retire → Verify

## Phases

- [ ] **Phase 1: Package & Local Verify** — Dockerfiles, health endpoints, config wiring, and local boot tests for both services.
- [ ] **Phase 2: Secrets & CI Image Push** — Gmail app password sealed into Git; CI builds and pushes both images to ECR on every push to `main`.
- [ ] **Phase 3: Chart, GitOps Deploy & Old-App Retirement** — Helm chart updated for `portfolio-web`/`portfolio-api` with security context and probes; Istio routing flipped; old FastAPI/EJS app removed; Flux reconciles.
- [ ] **Phase 4: Production Verification & Cutover Close-Out** — End-to-end checks on `https://yedressov.com`, including real contact-form email, rate-limit, body-size, CORS, and confirmation the old pods are gone.

## Phase Details

### Phase 1: Package & Local Verify
**Goal**: Both services build as reproducible, non-root container images and boot cleanly with all config read from env vars.
**Depends on**: Nothing (source trees already exist under `app/portfolio/`).
**Requirements**: PKG-01, PKG-02, PKG-03, PKG-04, PKG-05, APP-01, APP-02, APP-03, APP-04, APP-05, SEC-05, SEC-07
**Success Criteria** (what must be TRUE):
  1. `docker build` succeeds for both `app/portfolio/backend/` and `app/portfolio/frontend/` from a clean clone.
  2. Each container, run locally with the documented env vars, responds 200 on `GET /health`.
  3. The backend `POST /api/contact` rejects oversized bodies with 413 and enforces per-IP rate limiting before attempting SMTP.
  4. The frontend proxies `/api/*` requests to `API_URL` and applies `helmet()` with a CSP that works for the static pages.
  5. No secrets, `node_modules`, or `__pycache__` end up in either image layer.
**Plans**: TBD

### Phase 2: Secrets & CI Image Push
**Goal**: SMTP credentials live encrypted in Git and both container images are published to ECR automatically on `main`.
**Depends on**: Phase 1 (Dockerfiles must exist before CI can build them).
**Requirements**: SMS-01, SMS-02, SMS-03, SEC-02, CI-01, CI-02, CI-03, CI-04
**Success Criteria** (what must be TRUE):
  1. A Sealed Secret manifest containing `SMTP_USER`, `SMTP_PASS`, and `RECIPIENT_EMAIL` is committed under the chart/cluster tree and can be decrypted only by the in-cluster controller.
  2. Rotation instructions for the Gmail app password are documented in the chart `NOTES` or a `README`.
  3. A push to `main` that touches `app/portfolio/**` triggers a GitHub Actions workflow that builds both images and pushes them to the `portfolio-web` and `portfolio-api` ECR repos, tagged with both `latest` and the commit SHA.
  4. The Actions run fails fast on build errors and surfaces the resulting image digests in the job summary.
  5. Image promotion into the cluster is wired — either via Flux image automation watching the new ECR repos or via explicit Helm value bumps on release.
**Plans**: TBD

### Phase 3: Chart, GitOps Deploy & Old-App Retirement
**Goal**: Flux deploys the new `portfolio-web` + `portfolio-api` workloads with the sealed SMTP secret mounted, Istio routes traffic to them, and the old FastAPI/EJS app is gone from the cluster.
**Depends on**: Phase 2 (images must be in ECR and secret must be sealed before deploy).
**Requirements**: DEP-01, DEP-02, DEP-03, DEP-04, DEP-05, SEC-01, SEC-03, SEC-04, SEC-06
**Success Criteria** (what must be TRUE):
  1. `HelmCharts/portfolio/` deploys `portfolio-web` (3000) and `portfolio-api` (5000) with liveness/readiness probes, resource requests/limits, and a PSS-Restricted-compliant `securityContext` (non-root, no privilege escalation, dropped capabilities).
  2. The backend pod receives SMTP credentials via `envFrom.secretRef` pointing at the unsealed secret — no credentials appear in chart values or the pod spec.
  3. CORS on the backend is locked to `https://yedressov.com` (plus localhost for dev), and a NetworkPolicy or Istio AuthorizationPolicy restricts backend ingress to the frontend pod and ingress gateway.
  4. The Istio VirtualService bound to the existing `yedressov.com` Gateway sends `/api/*` to `portfolio-api:5000` and everything else to `portfolio-web:3000`.
  5. Flux reconciles the updated `clusters/dev-projectx/portfolio.yaml`, old FastAPI/EJS Deployments and Services are removed from the chart, and only the new workloads are rendered.
**Plans**: TBD

### Phase 4: Production Verification & Cutover Close-Out
**Goal**: The live site at `https://yedressov.com` serves the new portfolio, the contact form delivers real email, and all security guardrails are observable in production.
**Depends on**: Phase 3 (workloads must be live to verify).
**Requirements**: VER-01, VER-02, VER-03, VER-04, VER-05, VER-06, VER-07
**Success Criteria** (what must be TRUE):
  1. `curl https://yedressov.com/health` and `curl https://yedressov.com/api/health` both return 200 through the Istio gateway.
  2. A real contact-form submission from the live site lands in `contact@yedressov.com` within 30 seconds.
  3. The 6th submission from the same IP within the rate window is rejected with HTTP 429, and an over-sized body is rejected with HTTP 413 before SMTP is attempted.
  4. A CORS preflight from `https://evil.com` is rejected (no `Access-Control-Allow-Origin` echoed back).
  5. `kubectl -n portfolio get pods` shows only `portfolio-web` and `portfolio-api` pods — no old FastAPI pod remains.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Package & Local Verify | 0/? | Not started | - |
| 2. Secrets & CI Image Push | 0/? | Not started | - |
| 3. Chart, GitOps Deploy & Old-App Retirement | 0/? | Not started | - |
| 4. Production Verification & Cutover Close-Out | 0/? | Not started | - |
