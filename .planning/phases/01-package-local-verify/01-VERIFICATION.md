---
phase: 01-package-local-verify
type: verification
date: 2026-04-15
verifier: gsd-executor (claude opus 4.6)
host: darwin 24.2.0 (macOS) — Docker Desktop 29.0.1
---

# Phase 1 — Verification Report

Note on host ports: ports 3000 and 5000 were in use on the verification host
(macOS ControlCenter on :5000, a separate node dev server on :3000), so
container host ports were remapped to **13000** (frontend) and **15000**
(backend). Container-internal ports (3000 / 5000) and all env vars from
CONTEXT D-06 were unchanged. The `app/portfolio/README.md` documents the
canonical 3000/5000 mapping; the alternate ports are a host-side workaround
only.

## Per-plan results

### Plan 01 — Backend app hardening — PASS

```text
$ MAX_BODY_BYTES=100 python -c "<plan-verify script>"
OK: health + 413 handler wired correctly

$ MAX_BODY_BYTES=50 RATE_LIMIT=1 python -c "<plan-verify script>"
OK: 413 fires before rate-limit / validation / SMTP
```

Deviation: Flask's `MAX_CONTENT_LENGTH` does NOT pre-empt route handlers — it
raises only when the body is accessed. Adding `@app.errorhandler(413)` was
not enough; `_is_rate_limited` ran before `request.get_json()` triggered the
413, consuming a rate-limit slot. Fixed by adding a `@app.before_request`
hook that aborts oversized bodies before any handler runs (Rule 2 — required
to satisfy SEC-07 ordering guarantee).

### Plan 02 — Frontend `/health` — PASS

```text
$ PORT=3999 BACKEND_URL=http://127.0.0.1:1 node server.js
$ curl -fsS http://127.0.0.1:3999/health
{"status":"ok"}
OK: frontend /health 200 without backend
```

### Plan 03 — Backend Dockerfile — PASS

```text
$ docker build -t portfolio-api:plan01-03 app/portfolio/backend
[builder + runtime stages OK]
$ docker run --rm --entrypoint id portfolio-api:plan01-03
uid=10001(app) gid=10001(app) groups=10001(app)
$ docker run --rm --entrypoint sh portfolio-api:plan01-03 -c 'gunicorn --version'
gunicorn (version 23.0.0)
$ docker run --rm --entrypoint sh portfolio-api:plan01-03 -c 'ls -A /app'
app.py
```

Boot test:

```text
container /health        → 200 {"status":"ok"}
container /api/health    → 200 {"status":"ok","timestamp":...}
oversized POST           → 413
```

### Plan 04 — Frontend Dockerfile — PASS

```text
$ docker build -t portfolio-web:plan01-04 app/portfolio/frontend
[builder + runtime stages OK]
$ docker run --rm --entrypoint id portfolio-web:plan01-04
uid=10001(app) gid=10001(app) groups=10001(app),10001(app)
$ docker run --rm --entrypoint node portfolio-web:plan01-04 --version
v20.20.2
$ docker run --rm --entrypoint sh portfolio-web:plan01-04 -c 'ls -A /app'
node_modules
package.json
public
server.js
```

Boot test:

```text
container /health (BACKEND_URL=http://127.0.0.1:1) → 200 {"status":"ok"}
```

### Plan 05 — End-to-end local-verify protocol — PASS

```text
=== 3.1 Health endpoints ===
GET  http://localhost:13000/health     → 200 {"status":"ok"}     (frontend local)
GET  http://localhost:15000/health     → 200 {"status":"ok"}     (backend bare)
GET  http://localhost:15000/api/health → 200 {"status":"ok",...} (backend api)
GET  http://localhost:13000/api/health → 200 {"status":"ok",...} (proxied)

=== 3.2 413 body cap (MAX_BODY_BYTES=16384, 20KB body) ===
POST http://localhost:15000/api/contact → 413
body: {"error":"Payload too large.","success":false}

=== 3.3 Rate limit (RATE_LIMIT=5) ===
req 1 → 200
req 2 → 200
req 3 → 200
req 4 → 200
req 5 → 200
req 6 → 429

=== 3.4 Frontend proxy happy path ===
POST http://localhost:13000/api/contact → 200
body: {"message":"Message received (dev mode — email not sent).","success":true}

OK: full local-verify protocol passed
```

Deviation found and fixed during Plan 05: http-proxy-middleware v3 +
`app.use("/api", proxy)` strips the `/api` prefix before forwarding,
causing backend to receive `/contact` and 404. Rewrote proxy mount as
`app.use(createProxyMiddleware({ pathFilter: p => p.startsWith("/api"), ... }))`
so the original URL is preserved (Rule 1 bug fix).

## Outcomes summary

| Plan | Status | Notes |
|------|--------|-------|
| 01 backend hardening   | passed       | Added `before_request` body-cap hook (Rule 2) |
| 02 frontend `/health`  | passed       | — |
| 03 backend Dockerfile  | passed       | Image runs uid 10001, gunicorn boots cleanly |
| 04 frontend Dockerfile | passed       | Image runs uid 10001, Node v20, no dev artifacts |
| 05 local verify + README | passed     | Proxy bug fixed; full E2E passed |

## Human verification needed

None for Phase 1 functional criteria — the Plan 05 checkpoint (`task type=
"checkpoint:human-verify"`) asks the user to optionally re-run the protocol
and type "approved". All assertions have already passed via the executor;
the human gate is acknowledgement only.
