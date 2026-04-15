---
phase: 01-package-local-verify
status: complete
date-completed: 2026-04-15
plans-completed: 5
plans-total: 5
requirements-fulfilled: [PKG-01, PKG-02, PKG-03, PKG-04, PKG-05, APP-01, APP-02, APP-03, APP-04, APP-05, SEC-05, SEC-07]
key-files:
  created:
    - app/portfolio/backend/Dockerfile
    - app/portfolio/backend/.dockerignore
    - app/portfolio/frontend/Dockerfile
    - app/portfolio/frontend/.dockerignore
    - app/portfolio/README.md
    - .planning/phases/01-package-local-verify/01-VERIFICATION.md
  modified:
    - app/portfolio/backend/app.py
    - app/portfolio/frontend/server.js
commits:
  - f7ccfd2 feat(01): harden backend with /health, body cap, 413 handler
  - 8cb0ffc feat(01): add local /health route to frontend server
  - <auto> feat(01): add multi-stage non-root Dockerfile for portfolio-api
  - <auto> feat(01): add multi-stage non-root Dockerfile for portfolio-web
  - 0badc09 fix(01): preserve /api prefix when proxying to backend
  - 2e192a8 docs(01): add portfolio v2 local build & verify protocol
---

# Phase 1 — Package & Local Verify — Summary

Both portfolio services now build into reproducible, hardened, non-root
container images that boot cleanly and satisfy every Phase 1 success
criterion locally: bare /health endpoints, env-driven config, 413 body
cap enforced *before* rate-limit and SMTP, per-IP rate limit, locked CSP,
and the frontend proxies /api/* through to the backend.

## What changed

### `app/portfolio/backend/app.py`
- Added `app.config["MAX_CONTENT_LENGTH"] = int(os.getenv("MAX_BODY_BYTES", 16384))`
  immediately after `app = Flask(__name__)`.
- Added bare `GET /health` returning `200 {"status":"ok"}` alongside the
  existing `/api/health`.
- Added `@app.errorhandler(413)` returning the locked CONTEXT D-03 JSON.
- Added `@app.before_request` hook that aborts with 413 when
  `request.content_length > MAX_CONTENT_LENGTH`. Without this hook the
  Flask framework only enforces the cap when the body is actually parsed,
  which happens *after* the route handler has already run `_is_rate_limited`
  and could conceivably reach `_send_email`. Adding the before_request hook
  guarantees the SEC-07 ordering ("body-size rejection happens before SMTP")
  end-to-end.

### `app/portfolio/frontend/server.js`
- Added `app.get("/health", ...)` returning `200 {"status":"ok"}` between
  `compression()` and the API proxy mount, so it's never swallowed by the
  proxy or SPA fallback and is independent of backend reachability.
- Rewrote the `/api` proxy from `app.use("/api", createProxyMiddleware(...))`
  to `app.use(createProxyMiddleware({ pathFilter: p => p.startsWith("/api"), ...}))`.
  In http-proxy-middleware v3 the Express prefix-mount strips `/api` before
  forwarding, causing the backend to see `/contact` (404). The pathFilter
  function preserves the original URL.

### `app/portfolio/backend/Dockerfile` (new)
Multi-stage:
- `builder` (`python:3.12-slim-bookworm`): apt-installs `build-essential`,
  builds a venv at `/opt/venv`, `pip install --no-cache-dir -r requirements.txt`.
- `runtime` (`python:3.12-slim-bookworm`): copies `/opt/venv` and `app.py`,
  creates uid/gid 10001 `app` user, `USER app`, `EXPOSE 5000`,
  `CMD ["sh", "-c", "exec gunicorn -w 1 -b 0.0.0.0:${BACKEND_PORT:-5000} app:app"]`.

### `app/portfolio/frontend/Dockerfile` (new)
Multi-stage:
- `builder` (`node:20-alpine`): `npm ci --omit=dev` (or `npm install --omit=dev`
  if no lockfile present).
- `runtime` (`node:20-alpine`): copies `/build/node_modules`, `package.json`,
  `server.js`, `public/`. Creates uid/gid 10001 `app` user, `USER app`,
  `EXPOSE 3000`, `CMD ["node", "server.js"]`.

### `.dockerignore` (both services)
Excludes `.git`, env files, pycache/node_modules, tests, and all repo-level
noise (`.planning/`, `terraform-infra/`, `clusters/`, `platform-tools/`,
`HelmCharts/`, `.github/`, `*.md`).

### `app/portfolio/README.md`
Replaces the previous quick-start README with the Phase 1 reproduction
recipe (build, run with documented env vars, four health curls, 413 test,
429 test, frontend proxy happy path, cleanup).

## Deviations from PLANs

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Body-cap before-request hook**
- Found during: Plan 01 Task 2 verification.
- Issue: `app.config["MAX_CONTENT_LENGTH"]` alone allowed `_is_rate_limited`
  to run before the 413 fired (Flask defers the check until the body is
  parsed by the route handler), so 413'd requests still consumed
  rate-limit budget. Plan 01 explicitly anticipated this case.
- Fix: Added `@app.before_request` hook that inspects
  `request.content_length` and short-circuits with 413 before any handler
  runs. Now SEC-07 ordering ("body-size rejection happens before SMTP")
  is guaranteed end-to-end.
- File: `app/portfolio/backend/app.py`.
- Commit: `f7ccfd2`.

**2. [Rule 1 - Bug] http-proxy-middleware prefix stripping**
- Found during: Plan 05 Task 2 end-to-end verification.
- Issue: `app.use("/api", createProxyMiddleware(...))` strips `/api` before
  forwarding in http-proxy-middleware v3, so backend received `/contact`
  and returned 404 for `POST /api/contact`.
- Fix: Replaced the prefix mount with a root mount + `pathFilter` function
  so the original URL is preserved.
- File: `app/portfolio/frontend/server.js`.
- Commit: `0badc09`.

### Deferred / out of scope (per CONTEXT)

- CSP `'unsafe-inline'` left in place (CONTEXT specifics — Phase 4 hardening).
- Digest-pinning of base images deferred (CONTEXT D-01 — tag pin only).
- Multi-worker gunicorn + shared rate-limit store deferred (CONTEXT D-04).

## Verification

Full per-plan and end-to-end results captured in
`.planning/phases/01-package-local-verify/01-VERIFICATION.md`. Headline:
all 5 plans passed; the README's documented protocol passed end-to-end on
the host (with port remap 13000/15000 because the canonical 3000/5000 were
in use on the dev machine — container-internal ports are unchanged).

## Self-Check: PASSED

- Files exist:
  - `app/portfolio/backend/app.py` FOUND
  - `app/portfolio/backend/Dockerfile` FOUND
  - `app/portfolio/backend/.dockerignore` FOUND
  - `app/portfolio/frontend/server.js` FOUND
  - `app/portfolio/frontend/Dockerfile` FOUND
  - `app/portfolio/frontend/.dockerignore` FOUND
  - `app/portfolio/README.md` FOUND
- All commits present in `git log`.
