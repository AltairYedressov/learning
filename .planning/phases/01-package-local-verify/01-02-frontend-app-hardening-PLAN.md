---
phase: 01-package-local-verify
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - app/portfolio/frontend/server.js
autonomous: true
requirements: [APP-02, APP-04, SEC-05]
tags: [express, frontend, health, csp, proxy]

must_haves:
  truths:
    - "GET /health on the frontend returns 200 {status:'ok'} WITHOUT calling the backend."
    - "/health route is registered BEFORE the /api proxy and before the SPA catch-all, so it is never swallowed."
    - "GET /api/health is proxied to BACKEND_URL and returns whatever the backend returns (regression check)."
    - "helmet() CSP continues to serve the static portfolio pages without errors (SEC-05)."
  artifacts:
    - path: "app/portfolio/frontend/server.js"
      provides: "Express server with local /health route ordered before proxy + SPA fallback"
      contains: 'app.get("/health"'
  key_links:
    - from: "app.get('/health')"
      to: "literal 200 JSON response"
      via: "handler does NOT call BACKEND_URL"
      pattern: 'app\\.get\\(["\']/health["\']'
    - from: "/health registration"
      to: "must appear above app.use('/api', createProxyMiddleware...) and app.get('*', ...)"
      via: "source line order"
      pattern: "order-constraint"
---

<objective>
Add a local `/health` route to the Express frontend and confirm the existing
`helmet()` + CSP + `/api` proxy setup remain correct.

Purpose: Requirements APP-02 (frontend /health), APP-04 (API proxy still works),
SEC-05 (helmet CSP works for the static pages — already set up, verify only).

Output: Modified `app/portfolio/frontend/server.js` with a single new route.
No Dockerfile work in this plan — packaging happens in Plan 04.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/phases/01-package-local-verify/01-CONTEXT.md
@app/portfolio/frontend/server.js
@app/portfolio/frontend/package.json

<interfaces>
<!-- Existing Express app (server.js) already has, in this order: -->
<!--   1. helmet() + CSP directives                                -->
<!--   2. compression()                                             -->
<!--   3. app.use("/api", createProxyMiddleware(...))               -->
<!--   4. express.static(...)                                       -->
<!--   5. app.get("*", SPA fallback)                                -->
<!-- The new /health route MUST slot between step 2 and step 3,    -->
<!-- per CONTEXT D-02 + specifics block.                            -->
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add local /health route above /api proxy and SPA fallback</name>
  <files>app/portfolio/frontend/server.js</files>
  <behavior>
    - GET /health → 200, Content-Type application/json, body {"status":"ok"}.
    - Handler performs NO network call — pure literal response.
    - Placed after `app.use(compression())` and BEFORE
      `app.use("/api", createProxyMiddleware(...))` so proxy never sees it,
      and before `app.get("*", ...)` so SPA fallback never swallows it.
  </behavior>
  <action>
    Edit `app/portfolio/frontend/server.js`:

    Insert the following block immediately after the existing
    `app.use(compression());` line (currently line 33), and before the
    `// ── API Proxy ──` section:

    ```javascript
    // ── Local Health Probe ─────────────────────────────────────────────────────
    // Liveness/readiness probe — intentionally does NOT proxy to the backend.
    // Frontend liveness must be independent of backend reachability (CONTEXT D-02).
    app.get("/health", (_req, res) => {
      res.status(200).json({ status: "ok" });
    });
    ```

    Do NOT touch:
    - helmet()/CSP config (CONTEXT specifics: keep `'unsafe-inline'` for Phase 1).
    - /api proxy.
    - static / SPA fallback.
    - PORT / BACKEND_URL resolution.
  </action>
  <verify>
    <automated>cd app/portfolio/frontend &amp;&amp; npm install --omit=dev --silent &amp;&amp; node -e "
const http = require('http');
process.env.PORT = '0';
process.env.BACKEND_URL = 'http://127.0.0.1:1'; // unreachable on purpose
const app = require('./server.js'); // side-effect: listens on random port
// server.js calls app.listen; grab the port via a fresh supertest-style probe.
setTimeout(() => {
  // fallback: spin up an independent sanity check by requiring the file fresh
  // and asserting /health responds WITHOUT hitting the (unreachable) backend.
  process.exit(0);
}, 200);
" 2>&amp;1 || true
# Simpler: start server and curl it.
(cd app/portfolio/frontend &amp;&amp; PORT=3999 BACKEND_URL=http://127.0.0.1:1 node server.js &amp; echo $! &gt; /tmp/fe.pid; sleep 1)
CODE=$(curl -s -o /tmp/fe.body -w '%{http_code}' http://127.0.0.1:3999/health)
kill "$(cat /tmp/fe.pid)" 2&gt;/dev/null || true
test "$CODE" = "200" &amp;&amp; grep -q '"status":"ok"' /tmp/fe.body &amp;&amp; echo "OK: frontend /health 200 without backend"</automated>
  </verify>
  <done>
    - `curl http://127.0.0.1:3999/health` returns 200 `{"status":"ok"}` even
      when `BACKEND_URL` points at a closed port.
    - `/api/health` would still be proxied (not tested here — tested in
      Plan 05 end-to-end).
    - No helmet/CSP/proxy/SPA code changed.
  </done>
</task>

</tasks>

<verification>
The automated script above both installs dev-free deps and boots the server
against an unreachable backend to prove `/health` is answered locally.
</verification>

<success_criteria>
- `app/portfolio/frontend/server.js` contains `app.get("/health"` in the
  correct ordering slot.
- Automated verify prints `OK: frontend /health 200 without backend`.
- No other lines in server.js modified.
</success_criteria>

<output>
After completion, create
`.planning/phases/01-package-local-verify/01-02-SUMMARY.md` documenting the
diff and verification output.
</output>
