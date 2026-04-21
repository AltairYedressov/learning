---
phase: 01-package-local-verify
plan: 04
type: execute
wave: 2
depends_on: [02]
files_modified:
  - app/portfolio/frontend/Dockerfile
  - app/portfolio/frontend/.dockerignore
autonomous: true
requirements: [PKG-02, PKG-04, PKG-05]
tags: [docker, frontend, node, non-root]

must_haves:
  truths:
    - "docker build -t portfolio-web app/portfolio/frontend succeeds from a clean clone."
    - "Image runs as uid 10001 non-root."
    - "Container CMD is `node server.js` and binds PORT (default 3000)."
    - "Base image pinned to node:20-alpine per CONTEXT D-01 and PKG-05."
    - "node_modules and dev artifacts are NOT present in final image aside from the production install baked in."
  artifacts:
    - path: "app/portfolio/frontend/Dockerfile"
      provides: "Multi-stage Node image — builder runs npm ci --omit=dev, final copies node_modules + source, runs non-root"
      contains: "FROM node:20-alpine"
      contains_user: "USER"
    - path: "app/portfolio/frontend/.dockerignore"
      provides: "Excludes node_modules, .env*, dev artifacts, repo-level noise"
      contains: "node_modules"
  key_links:
    - from: "builder stage"
      to: "final stage via COPY --from=builder node_modules"
      via: "multi-stage copy"
      pattern: "COPY --from=builder"
    - from: "non-root USER"
      to: "uid 10001"
      via: "addgroup/adduser"
      pattern: "USER app"
---

<objective>
Produce a production Dockerfile for the portfolio frontend that satisfies
PKG-02 (Node 20 image, Express on port 3000, non-root), PKG-04
(.dockerignore hygiene), and PKG-05 (pinned base tag).

Purpose: Reproducible hardened image ready for Phase 2 CI + Phase 3 Helm chart.

Output: New `app/portfolio/frontend/Dockerfile` and
`app/portfolio/frontend/.dockerignore`. The old-app frontend Dockerfile at
`app/frontend/Dockerfile` is a style reference only — do NOT edit it.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/phases/01-package-local-verify/01-CONTEXT.md
@app/portfolio/frontend/server.js
@app/portfolio/frontend/package.json
@app/frontend/Dockerfile
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write frontend Dockerfile (multi-stage, non-root)</name>
  <files>app/portfolio/frontend/Dockerfile</files>
  <action>
    Create `app/portfolio/frontend/Dockerfile` with the following content
    (CONTEXT D-01, D-04, D-05 are authoritative):

    ```dockerfile
    # syntax=docker/dockerfile:1.7

    # ── Builder stage: install production deps ─────────────────────────────────
    FROM node:20-alpine AS builder

    ENV NODE_ENV=production
    WORKDIR /build

    # If a lockfile exists prefer `npm ci` for determinism; fall back to `npm install`.
    COPY package.json ./
    COPY package-lock.json* ./
    RUN if [ -f package-lock.json ]; then \
          npm ci --omit=dev --no-audit --no-fund; \
        else \
          npm install --omit=dev --no-audit --no-fund; \
        fi

    # ── Final stage: minimal runtime ───────────────────────────────────────────
    FROM node:20-alpine AS runtime

    ENV NODE_ENV=production \
        PORT=3000

    # Non-root principal (CONTEXT D-05: uid/gid 10001)
    RUN addgroup -g 10001 -S app \
     && adduser  -u 10001 -S app -G app -h /app -s /sbin/nologin

    WORKDIR /app

    # Copy installed modules from builder
    COPY --from=builder --chown=app:app /build/node_modules ./node_modules
    COPY --from=builder --chown=app:app /build/package.json ./package.json

    # Copy application source (server.js + public/ + views/ if present)
    COPY --chown=app:app server.js ./server.js
    # Conditionally copy public/ if it exists in build context (CI should scaffold it).
    # The portfolio static assets live in ./public — we include whatever ships.
    COPY --chown=app:app public ./public

    USER app

    EXPOSE 3000

    CMD ["node", "server.js"]
    ```

    Notes on the `COPY --chown=app:app public ./public` line: if `public/`
    does not yet exist in the source tree, the build will fail. Per
    CONTEXT this is the expected layout for the portfolio app; if the
    directory is legitimately absent when this plan executes, raise a
    checker-visible error rather than silently succeeding — the static
    site requires it.
  </action>
  <verify>
    <automated>docker build -t portfolio-web:plan01-04 app/portfolio/frontend &amp;&amp; \
docker run --rm --entrypoint id portfolio-web:plan01-04 | grep -q 'uid=10001' &amp;&amp; \
docker run --rm --entrypoint node portfolio-web:plan01-04 --version | grep -q '^v20' &amp;&amp; \
echo "OK: image builds, runs as uid 10001, Node v20"</automated>
  </verify>
  <done>
    - `docker build` exits 0.
    - Container runs as uid 10001.
    - Node version is v20.
    - Base line literally reads `FROM node:20-alpine` in both stages.
  </done>
</task>

<task type="auto">
  <name>Task 2: Write frontend .dockerignore</name>
  <files>app/portfolio/frontend/.dockerignore</files>
  <action>
    Create `app/portfolio/frontend/.dockerignore`:

    ```gitignore
    # VCS
    .git
    .gitignore

    # Node artifacts — we reinstall inside the builder stage
    node_modules
    npm-debug.log
    yarn-debug.log
    yarn-error.log

    # Env / secrets
    .env
    .env.*

    # Tests & dev artifacts
    tests/
    *.test.js
    coverage/

    # Repo-level noise
    .planning/
    terraform-infra/
    clusters/
    platform-tools/
    HelmCharts/
    .github/
    *.md

    # Editor / OS
    .vscode/
    .idea/
    .DS_Store
    ```
  </action>
  <verify>
    <automated>docker build -t portfolio-web:plan01-04 app/portfolio/frontend &amp;&amp; \
docker run --rm --entrypoint sh portfolio-web:plan01-04 -c 'ls -A /app' | tee /tmp/fels.out &amp;&amp; \
! grep -qE '^\.env$|^\.git$' /tmp/fels.out &amp;&amp; \
grep -q 'node_modules' /tmp/fels.out &amp;&amp; \
echo "OK: node_modules from builder present, dev artifacts excluded"</automated>
  </verify>
  <done>
    - `.dockerignore` present.
    - Image `/app` has `node_modules` (copied from builder stage, not from
      build context) but no `.env*` or `.git`.
  </done>
</task>

<task type="auto">
  <name>Task 3: Boot-test container and hit /health</name>
  <files>app/portfolio/frontend/Dockerfile</files>
  <action>
    No code changes. Boot the frontend container and confirm `/health`
    returns 200 without a backend running (proves APP-02 and Plan 02's
    ordering fix survived into the image).
  </action>
  <verify>
    <automated>docker rm -f pf-web-test 2&gt;/dev/null; \
docker run -d --name pf-web-test -p 13000:3000 -e BACKEND_URL=http://127.0.0.1:1 portfolio-web:plan01-04 &amp;&amp; \
sleep 2 &amp;&amp; \
curl -fsS http://127.0.0.1:13000/health | grep -q '"status":"ok"' &amp;&amp; \
docker rm -f pf-web-test &amp;&amp; \
echo "OK: frontend container healthy without backend"</automated>
  </verify>
  <done>
    - Frontend container serves `/health` 200 even with `BACKEND_URL`
      pointed at a closed port.
    - Container cleaned up after test.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| host → container | Untrusted HTTP ingress on port 3000 |
| container → backend | Proxy out to BACKEND_URL (untrusted egress target pre-mTLS) |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-04-01 | Elevation of Privilege | node process | mitigate | Non-root uid 10001; USER before CMD |
| T-01-04-02 | Information Disclosure | image layers | mitigate | `.dockerignore` excludes `.env*`, `.git`, planning/infra dirs |
| T-01-04-03 | Tampering | npm deps | mitigate | `npm ci` when lockfile present; deterministic install; base pinned |
| T-01-04-04 | Tampering | base image | accept | Tag pin `node:20-alpine`; digest pin deferred per CONTEXT |
</threat_model>

<verification>
All three automated checks pass. Test containers cleaned up.
</verification>

<success_criteria>
- `app/portfolio/frontend/Dockerfile` multi-stage, pinned base, non-root.
- `.dockerignore` present with CONTEXT D-07 entries.
- Image builds and serves `/health` without a live backend.
</success_criteria>

<output>
After completion, create
`.planning/phases/01-package-local-verify/01-04-SUMMARY.md`.
</output>
