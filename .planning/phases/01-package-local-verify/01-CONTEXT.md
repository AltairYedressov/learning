---
phase: 1
name: Package & Local Verify
status: ready-for-planning
---

# Phase 1: Package & Local Verify — Context

**Gathered:** 2026-04-15
**Mode:** Interactive (autonomous --interactive)

<domain>
## Phase Boundary

Both `app/portfolio/backend` (Flask) and `app/portfolio/frontend` (Express)
become reproducible, non-root container images that boot cleanly with all
config read from env vars, and satisfy the success-criteria guardrails
(health endpoints, 413 body cap, per-IP rate limit, locked CSP, non-root).

Scope is **packaging + local verification only**. No cluster deploy, no CI,
no secrets management — those are Phases 2–4.

</domain>

<decisions>
## Implementation Decisions (Locked)

### 1. Base image strategy
- **Backend:** `python:3.12-slim-bookworm` (multi-stage: builder installs
  deps into a venv, final stage copies venv + app, runs as non-root uid).
- **Frontend:** `node:20-alpine` (multi-stage: `npm ci --omit=dev` in
  builder, final stage copies `node_modules` + source, runs as non-root).
- Rationale: matches repo conventions (existing Dockerfiles in `app/frontend`
  and `app/backend`), small footprint, well-supported.

### 2. Health endpoints
- **Backend:** expose BOTH `/health` (new, bare) AND `/api/health` (existing).
  Container probes use `/health`; external probes via ingress stay on
  `/api/health`.
- **Frontend:** add local `/health` route that returns `{status: "ok"}`
  WITHOUT proxying to the backend (so frontend liveness ≠ backend reach).
  Must be registered **before** the `/api` proxy and `*` SPA fallback.
- Rationale: satisfies success criterion #2 literally ("each container
  responds 200 on GET /health") while preserving the existing `/api/health`
  path used by external verification scripts.

### 3. Request body-size limit (backend)
- Set `app.config["MAX_CONTENT_LENGTH"]` from env `MAX_BODY_BYTES`
  (default `16384` / 16 KB).
- Register an explicit `@app.errorhandler(413)` returning
  `{"success": false, "error": "Payload too large."}` with status 413.
- This guarantees Flask rejects oversized bodies **before** the contact
  handler (and therefore before any SMTP attempt), satisfying criterion #3.

### 4. App server
- **Backend:** `gunicorn -w 1 -b 0.0.0.0:${BACKEND_PORT:-5000} app:app`
  (single worker). Keeps the in-memory rate-limiter state coherent for
  Phase 1 local-verify; scaling concerns are a Phase 3 problem.
- **Frontend:** `node server.js` (express, unchanged).

### 5. Non-root / security context
- Create a dedicated user (uid 10001, gid 10001) in each image; `USER`
  directive set before `CMD`.
- No `sudo`, no package-manager caches in final layer, `--no-install-recommends`
  for apt; `apk --no-cache` for alpine.
- Filesystem: app files owned by the app user, no writes needed at runtime
  (readOnlyRootFilesystem-compatible for Phase 3).

### 6. Config surface (env vars)
| Service  | Variable               | Default                     |
| -------- | ---------------------- | --------------------------- |
| backend  | `BACKEND_PORT`         | `5000`                      |
| backend  | `SMTP_HOST`            | `smtp.gmail.com`            |
| backend  | `SMTP_PORT`            | `587`                       |
| backend  | `SMTP_USER`            | (unset → dev-mode log-only) |
| backend  | `SMTP_PASS`            | (unset → dev-mode log-only) |
| backend  | `RECIPIENT_EMAIL`      | `contact@yedressov.com`     |
| backend  | `ALLOWED_ORIGINS`      | `http://localhost:3000`     |
| backend  | `RATE_LIMIT`           | `5`                         |
| backend  | `RATE_WINDOW_MINUTES`  | `15`                        |
| backend  | `MAX_BODY_BYTES`       | `16384`                     |
| frontend | `PORT`                 | `3000`                      |
| frontend | `BACKEND_URL`          | `http://localhost:5000`     |
| frontend | `NODE_ENV`             | `production` (in image)     |

No secrets baked into images. `.env` only used for local dev.

### 7. Image hygiene (.dockerignore)
- Exclude: `.git`, `node_modules`, `__pycache__`, `*.pyc`, `venv/`, `.env*`,
  `tests/`, `.planning/`, `terraform-infra/`, `clusters/`, `platform-tools/`,
  `HelmCharts/`, `.github/`, `*.md` (except chart NOTES where applicable).
- Satisfies criterion #5 (no secrets, no dev artifacts in layers).

### 8. Local verification protocol
Documented in a short `app/portfolio/README.md` section:
- `docker build` each image from a clean clone.
- `docker run` each with the env vars above.
- `curl localhost:3000/health` → 200, `curl localhost:5000/health` → 200.
- `curl -X POST localhost:5000/api/contact -d @big.json` (>16 KB) → 413.
- Repeat `POST /api/contact` ≥ 6× from same IP in window → 429 on 6th.
- Frontend `/api/contact` proxies through to backend successfully.

</decisions>

<code_context>
## Existing Code Insights (already verified)

- Backend (`app/portfolio/backend/app.py`): Flask 3.1 + flask-cors +
  gunicorn already in `requirements.txt`. Rate limiter (`_is_rate_limited`)
  and `_validate_payload` exist. CORS origins from `ALLOWED_ORIGINS`.
  Missing: bare `/health`, `MAX_CONTENT_LENGTH`, 413 handler.
- Frontend (`app/portfolio/frontend/server.js`): Express 4 + helmet + CSP
  + http-proxy-middleware + compression already set up. CSP allows
  `'unsafe-inline'` for script/style. Missing: `/health` route.
- Repo already has Dockerfile examples in `app/frontend` and `app/backend`
  for the OLD portfolio app — use as style reference, but new Dockerfiles
  live under `app/portfolio/{backend,frontend}/Dockerfile`.

</code_context>

<specifics>
## Specific Ideas

- Frontend `/health` must be registered **before** both the `/api` proxy
  mount and the `app.get("*", ...)` SPA fallback, or it will be swallowed.
- CSP currently allows `'unsafe-inline'` for scripts; do NOT tighten in
  Phase 1 (would risk breaking the static portfolio pages). Revisit in
  Phase 4 hardening if requirements demand it.
- Keep `SMTP_USER`/`SMTP_PASS` unset during local verify — the backend
  already has a "dev mode" branch that logs instead of sending. This lets
  us exercise rate-limit and 413 paths without real SMTP.

</specifics>

<deferred>
## Deferred Ideas

- Distroless / chainguard base images — revisit if Phase 4 security review
  flags the slim/alpine surface area.
- Multi-worker gunicorn + shared rate-limit store (redis) — deferred to
  Phase 3 if we decide to scale replicas > 1.
- Tightening CSP (removing `'unsafe-inline'`) — deferred to Phase 4.
- SBOM / image signing (cosign) — out of scope for this milestone.

</deferred>

<canonical_refs>
## Canonical References

- `.planning/ROADMAP.md` — Phase 1 goal + success criteria
- `.planning/REQUIREMENTS.md` — PKG-01..05, APP-01..05, SEC-05, SEC-07
- `app/portfolio/backend/app.py` — existing Flask app
- `app/portfolio/frontend/server.js` — existing Express app
- `app/portfolio/backend/requirements.txt`
- `app/portfolio/frontend/package.json`
- `app/backend/Dockerfile`, `app/frontend/Dockerfile` — style reference (old app)

</canonical_refs>
