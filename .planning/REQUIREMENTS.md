# Requirements — Portfolio v2 Deployment

Derived from `.planning/PROJECT.md`. REQ-IDs are stable handles used by ROADMAP.md and phase plans.

## v1 Requirements

### Packaging (PKG)

- [ ] **PKG-01**: A production `Dockerfile` exists under `app/portfolio/backend/` that builds a slim image running Flask via gunicorn on port 5000, using a non-root user.
- [ ] **PKG-02**: A production `Dockerfile` exists under `app/portfolio/frontend/` that builds a Node 20 image serving Express on port 3000, using a non-root user.
- [ ] **PKG-03**: Both Dockerfiles pass a local `docker build` and container boot test (health endpoint responds).
- [ ] **PKG-04**: `.dockerignore` files exclude `node_modules`, `__pycache__`, `.env*`, and local dev artifacts from both images.
- [ ] **PKG-05**: Images are pinned to explicit base-image tags (digest preferred) for reproducibility.

### Application Health & Config (APP)

- [ ] **APP-01**: Backend exposes a `GET /health` endpoint returning 200 for Kubernetes liveness/readiness probes.
- [ ] **APP-02**: Frontend exposes a `GET /health` endpoint returning 200 for Kubernetes liveness/readiness probes.
- [ ] **APP-03**: Backend reads all configuration (`SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `RECIPIENT_EMAIL`, `ALLOWED_ORIGINS`, `RATE_LIMIT`, `RATE_WINDOW_MINUTES`, `MAX_BODY_SIZE`) from environment variables with safe defaults.
- [ ] **APP-04**: Frontend `server.js` proxies `/api/*` to the backend service via `API_URL` env var (default `http://portfolio-api:5000`).
- [ ] **APP-05**: Contact form endpoint (`POST /api/contact`) validates inputs, enforces rate limiting per-IP, and enforces body size cap before attempting SMTP send.

### Security (SEC)

- [ ] **SEC-01**: CORS on the backend is restricted to `https://yedressov.com` (and `http://localhost:3000` for dev) — no wildcards.
- [ ] **SEC-02**: SMTP credentials are stored as a Sealed Secret encrypted to the cluster's controller key, committed to Git under the Helm chart or `clusters/dev-projectx/`.
- [ ] **SEC-03**: The K8s Secret decrypted from the Sealed Secret is mounted into the backend pod via `envFrom.secretRef` — no credentials baked into images or chart values.
- [ ] **SEC-04**: Both pods run as non-root, with a restrictive `securityContext` (readOnlyRootFilesystem where feasible, no privilege escalation, drop all capabilities), satisfying the cluster's Kyverno PSS-Restricted policy.
- [ ] **SEC-05**: Frontend uses `helmet()` middleware with CSP appropriate for the static site (no inline scripts outside what the bundled pages ship).
- [ ] **SEC-06**: Network policy (or Istio AuthorizationPolicy) limits backend ingress to traffic from the frontend pod and the ingress gateway only.
- [ ] **SEC-07**: Backend denies requests exceeding `MAX_BODY_SIZE` with HTTP 413 before parsing.

### Secrets Management (SMS)

- [ ] **SMS-01**: A Gmail app password is generated (documented handoff in the phase), never committed in plaintext.
- [ ] **SMS-02**: Sealed Secret manifest for SMTP creds exists in Git and can be re-sealed if the controller key rotates.
- [ ] **SMS-03**: A `README` or chart NOTES clearly documents how to rotate the Gmail app password.

### Deployment (DEP)

- [ ] **DEP-01**: `HelmCharts/portfolio/` (or a replacement chart) is updated to deploy the new `portfolio-web` (frontend) and `portfolio-api` (backend) with correct image refs, probes, resources, and security context.
- [ ] **DEP-02**: Istio VirtualService routes `/api/` to `portfolio-api:5000` and all other paths to `portfolio-web:3000`, both bound to the existing Istio Gateway at `yedressov.com`.
- [ ] **DEP-03**: Flux Kustomization in `clusters/dev-projectx/portfolio.yaml` reconciles the updated HelmRelease on every push to `main`.
- [ ] **DEP-04**: Old FastAPI backend (`app/backend/`) and EJS frontend (`app/frontend/`) manifests are removed from the Helm chart; source trees can remain until post-deploy cleanup.
- [ ] **DEP-05**: Resource requests/limits are set conservatively (CPU 100m req / 250m limit, Mem 128Mi req / 256Mi limit per pod, tunable).

### CI / Image Registry (CI)

- [ ] **CI-01**: GitHub Actions workflow builds `portfolio-web` and `portfolio-api` images on push to `main` under `app/portfolio/**` and tags them with both `latest` and the commit SHA.
- [ ] **CI-02**: Images push to the existing ECR registry under tagged repositories (`portfolio-web`, `portfolio-api`), authenticated via the existing GitHub OIDC role.
- [ ] **CI-03**: Workflow fails fast on Dockerfile build errors; image digests are surfaced in the Actions summary.
- [ ] **CI-04**: Flux image reflector / automation (if already installed) is wired to watch the new ECR repos; otherwise Helm values are bumped explicitly on each release.

### Verification (VER)

- [ ] **VER-01**: Post-deploy, `curl https://yedressov.com/health` returns 200 via Istio → frontend.
- [ ] **VER-02**: Post-deploy, `curl https://yedressov.com/api/health` returns 200 via Istio → backend.
- [ ] **VER-03**: A real contact-form submission from `https://yedressov.com` lands an email in `contact@yedressov.com` within 30 seconds.
- [ ] **VER-04**: 6th contact-form submission from the same IP within the rate window returns HTTP 429.
- [ ] **VER-05**: A submission with body > `MAX_BODY_SIZE` returns HTTP 413 before SMTP is attempted.
- [ ] **VER-06**: CORS preflight from `https://evil.com` is rejected (no `Access-Control-Allow-Origin` echo).
- [ ] **VER-07**: Old FastAPI pod is no longer running in the `portfolio` namespace; only `portfolio-web` and `portfolio-api` pods remain for the app.

## v2 (Deferred)

- CAPTCHA / bot protection on `/api/contact` (revisit if spam appears)
- Persistent log of submissions (currently email-only audit trail)
- E2E browser tests (Playwright) hitting `yedressov.com`
- Frontend content CMS or data-driven rendering
- Image signing & admission verification (cosign + policy)
- Multi-environment (staging cluster)

## Out of Scope

- **Paid SMTP providers** — user requires a free contact-form; Gmail's 100/day ceiling is acceptable for a personal portfolio.
- **Blue/green or canary rollout** — hard cutover is acceptable; no SLA requires zero downtime.
- **Authentication on the site** — portfolio is public by design; no login surface.
- **External Secrets Operator** — Sealed Secrets is already installed and sufficient.
- **WAF / Shield in front of NLB** — out-of-scope for this milestone; baseline hardening is sufficient for portfolio-scale traffic.
- **Dedicated prod cluster** — `dev-projectx` is the only cluster; no prod/stage split this milestone.

## Traceability

Every v1 REQ-ID maps to exactly one phase. 34/34 mapped.

| REQ-ID | Phase | Plan |
|--------|-------|------|
| PKG-01 | Phase 1 — Package & Local Verify | TBD |
| PKG-02 | Phase 1 — Package & Local Verify | TBD |
| PKG-03 | Phase 1 — Package & Local Verify | TBD |
| PKG-04 | Phase 1 — Package & Local Verify | TBD |
| PKG-05 | Phase 1 — Package & Local Verify | TBD |
| APP-01 | Phase 1 — Package & Local Verify | TBD |
| APP-02 | Phase 1 — Package & Local Verify | TBD |
| APP-03 | Phase 1 — Package & Local Verify | TBD |
| APP-04 | Phase 1 — Package & Local Verify | TBD |
| APP-05 | Phase 1 — Package & Local Verify | TBD |
| SEC-05 | Phase 1 — Package & Local Verify | TBD |
| SEC-07 | Phase 1 — Package & Local Verify | TBD |
| SMS-01 | Phase 2 — Secrets & CI Image Push | TBD |
| SMS-02 | Phase 2 — Secrets & CI Image Push | TBD |
| SMS-03 | Phase 2 — Secrets & CI Image Push | TBD |
| SEC-02 | Phase 2 — Secrets & CI Image Push | TBD |
| CI-01  | Phase 2 — Secrets & CI Image Push | TBD |
| CI-02  | Phase 2 — Secrets & CI Image Push | TBD |
| CI-03  | Phase 2 — Secrets & CI Image Push | TBD |
| CI-04  | Phase 2 — Secrets & CI Image Push | TBD |
| DEP-01 | Phase 3 — Chart, GitOps Deploy & Old-App Retirement | TBD |
| DEP-02 | Phase 3 — Chart, GitOps Deploy & Old-App Retirement | TBD |
| DEP-03 | Phase 3 — Chart, GitOps Deploy & Old-App Retirement | TBD |
| DEP-04 | Phase 3 — Chart, GitOps Deploy & Old-App Retirement | TBD |
| DEP-05 | Phase 3 — Chart, GitOps Deploy & Old-App Retirement | TBD |
| SEC-01 | Phase 3 — Chart, GitOps Deploy & Old-App Retirement | TBD |
| SEC-03 | Phase 3 — Chart, GitOps Deploy & Old-App Retirement | TBD |
| SEC-04 | Phase 3 — Chart, GitOps Deploy & Old-App Retirement | TBD |
| SEC-06 | Phase 3 — Chart, GitOps Deploy & Old-App Retirement | TBD |
| VER-01 | Phase 4 — Production Verification & Cutover Close-Out | TBD |
| VER-02 | Phase 4 — Production Verification & Cutover Close-Out | TBD |
| VER-03 | Phase 4 — Production Verification & Cutover Close-Out | TBD |
| VER-04 | Phase 4 — Production Verification & Cutover Close-Out | TBD |
| VER-05 | Phase 4 — Production Verification & Cutover Close-Out | TBD |
| VER-06 | Phase 4 — Production Verification & Cutover Close-Out | TBD |
| VER-07 | Phase 4 — Production Verification & Cutover Close-Out | TBD |
