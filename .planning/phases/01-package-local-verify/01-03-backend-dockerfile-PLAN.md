---
phase: 01-package-local-verify
plan: 03
type: execute
wave: 2
depends_on: [01]
files_modified:
  - app/portfolio/backend/Dockerfile
  - app/portfolio/backend/.dockerignore
autonomous: true
requirements: [PKG-01, PKG-04, PKG-05]
tags: [docker, backend, gunicorn, non-root]

must_haves:
  truths:
    - "docker build -t portfolio-api app/portfolio/backend succeeds from a clean clone."
    - "Resulting image runs as a non-root user (uid 10001) when started."
    - "Container CMD is gunicorn binding 0.0.0.0:${BACKEND_PORT:-5000}."
    - "Base image is pinned to an explicit tag (python:3.12-slim-bookworm) per PKG-05."
    - ".dockerignore excludes .git, __pycache__, *.pyc, venv/, .env*, tests/, .planning/, etc."
  artifacts:
    - path: "app/portfolio/backend/Dockerfile"
      provides: "Multi-stage build: builder installs venv, final copies venv + app, runs non-root"
      contains: "FROM python:3.12-slim-bookworm"
      contains_also: "USER"
      contains_gunicorn: "gunicorn"
    - path: "app/portfolio/backend/.dockerignore"
      provides: "Layer hygiene — excludes dev artifacts and secrets"
      contains: "__pycache__"
  key_links:
    - from: "final-stage CMD"
      to: "gunicorn app:app on ${BACKEND_PORT}"
      via: "exec-form CMD with shell expansion via ENV"
      pattern: "gunicorn.*app:app"
    - from: "USER directive"
      to: "uid 10001 non-root principal"
      via: "RUN groupadd/useradd + USER appuser"
      pattern: "USER appuser"
---

<objective>
Produce a production Dockerfile for the new portfolio backend that satisfies
PKG-01 (slim Python image, gunicorn, non-root, port 5000), PKG-04
(.dockerignore hygiene), and PKG-05 (pinned base tag).

Purpose: Create a reproducible, hardened container image ready to be
consumed by Phase 2 CI and Phase 3 Helm chart.

Output: New `app/portfolio/backend/Dockerfile` and
`app/portfolio/backend/.dockerignore`. The old-app Dockerfile at
`app/backend/Dockerfile` is a style reference only — do NOT edit it.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/phases/01-package-local-verify/01-CONTEXT.md
@app/portfolio/backend/app.py
@app/portfolio/backend/requirements.txt
@app/backend/Dockerfile
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write backend Dockerfile (multi-stage, non-root, gunicorn)</name>
  <files>app/portfolio/backend/Dockerfile</files>
  <action>
    Create `app/portfolio/backend/Dockerfile` with the following content
    (CONTEXT D-01, D-04, D-05 are authoritative):

    ```dockerfile
    # syntax=docker/dockerfile:1.7

    # ── Builder stage: install deps into a venv ────────────────────────────────
    FROM python:3.12-slim-bookworm AS builder

    ENV PYTHONDONTWRITEBYTECODE=1 \
        PYTHONUNBUFFERED=1 \
        PIP_NO_CACHE_DIR=1 \
        PIP_DISABLE_PIP_VERSION_CHECK=1

    WORKDIR /build

    RUN apt-get update \
     && apt-get install -y --no-install-recommends build-essential \
     && rm -rf /var/lib/apt/lists/*

    RUN python -m venv /opt/venv
    ENV PATH="/opt/venv/bin:$PATH"

    COPY requirements.txt .
    RUN pip install --no-cache-dir -r requirements.txt

    # ── Final stage: minimal runtime ───────────────────────────────────────────
    FROM python:3.12-slim-bookworm AS runtime

    ENV PYTHONDONTWRITEBYTECODE=1 \
        PYTHONUNBUFFERED=1 \
        PATH="/opt/venv/bin:$PATH" \
        BACKEND_PORT=5000

    # Non-root principal (CONTEXT D-05: uid/gid 10001)
    RUN groupadd --system --gid 10001 app \
     && useradd  --system --uid 10001 --gid app --home /app --shell /usr/sbin/nologin app

    WORKDIR /app

    # Copy virtualenv from builder
    COPY --from=builder /opt/venv /opt/venv

    # Copy application source (owned by app user)
    COPY --chown=app:app app.py ./

    USER app

    EXPOSE 5000

    # gunicorn single-worker (CONTEXT D-04). Using shell form so ${BACKEND_PORT}
    # expands at container start time.
    CMD ["sh", "-c", "exec gunicorn -w 1 -b 0.0.0.0:${BACKEND_PORT:-5000} app:app"]
    ```

    Notes:
    - Base tag is an explicit Debian codename (`bookworm`) for PKG-05
      reproducibility. A digest pin is preferable but deferred — using a
      codename tag is the locked compromise from CONTEXT D-01.
    - `build-essential` is installed ONLY in the builder stage; the final
      runtime stage does not carry the toolchain.
    - `--no-install-recommends` + apt lists cleanup keeps the final image
      small and satisfies the image-hygiene locked decision.
    - Do NOT copy `requirements.txt` into the final stage — the venv is
      already provisioned and copying it would just add weight.
  </action>
  <verify>
    <automated>docker build -t portfolio-api:plan01-03 app/portfolio/backend &amp;&amp; \
docker run --rm --entrypoint id portfolio-api:plan01-03 | tee /tmp/id.out | grep -q 'uid=10001' &amp;&amp; \
docker run --rm --entrypoint sh portfolio-api:plan01-03 -c 'gunicorn --version' | grep -qi gunicorn &amp;&amp; \
echo "OK: image builds, runs as uid 10001, gunicorn present"</automated>
  </verify>
  <done>
    - `docker build` exits 0.
    - `docker run ... id` shows `uid=10001`.
    - Gunicorn is callable inside the image.
    - Base image line literally reads `FROM python:3.12-slim-bookworm`.
  </done>
</task>

<task type="auto">
  <name>Task 2: Write backend .dockerignore</name>
  <files>app/portfolio/backend/.dockerignore</files>
  <action>
    Create `app/portfolio/backend/.dockerignore` with the entries locked in
    CONTEXT D-07:

    ```gitignore
    # VCS
    .git
    .gitignore

    # Python artifacts
    __pycache__
    *.pyc
    *.pyo
    *.pyd
    .pytest_cache
    .mypy_cache
    .ruff_cache
    venv/
    .venv/

    # Env / secrets
    .env
    .env.*

    # Tests & dev artifacts
    tests/
    test_*.py

    # Repo-level noise that must never land in a service image
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
    <automated>docker build -t portfolio-api:plan01-03 app/portfolio/backend &amp;&amp; \
docker run --rm --entrypoint sh portfolio-api:plan01-03 -c 'ls -A /app' | tee /tmp/appls.out &amp;&amp; \
! grep -qE '__pycache__|\.env|\.git' /tmp/appls.out &amp;&amp; \
echo "OK: no dev artifacts in image /app"</automated>
  </verify>
  <done>
    - `.dockerignore` present with all entries listed in CONTEXT D-07.
    - Image `/app` contains only `app.py` (and whatever the chown line
      intentionally copied).
    - No `__pycache__`, `.env*`, `.git` present.
  </done>
</task>

<task type="auto">
  <name>Task 3: Boot-test container with health probe</name>
  <files>app/portfolio/backend/Dockerfile</files>
  <action>
    No code changes. Run a container from the image built in Task 1 and
    assert both `/health` (bare, from Plan 01) and `/api/health` (pre-existing)
    respond 200. Also assert 413 enforcement works through gunicorn with the
    default `MAX_BODY_BYTES=16384`.
  </action>
  <verify>
    <automated>docker rm -f pf-api-test 2&gt;/dev/null; \
docker run -d --name pf-api-test -p 15000:5000 -e MAX_BODY_BYTES=100 portfolio-api:plan01-03 &amp;&amp; \
sleep 2 &amp;&amp; \
curl -fsS http://127.0.0.1:15000/health | grep -q '"status":"ok"' &amp;&amp; \
curl -fsS http://127.0.0.1:15000/api/health | grep -q '"status":"ok"' &amp;&amp; \
BIG=$(python3 -c "print('x'*500)") &amp;&amp; \
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -d "\"$BIG\"" http://127.0.0.1:15000/api/contact) &amp;&amp; \
test "$CODE" = "413" &amp;&amp; \
docker rm -f pf-api-test &amp;&amp; \
echo "OK: container boots, /health 200, /api/health 200, oversized POST 413"</automated>
  </verify>
  <done>
    - Container starts cleanly under gunicorn.
    - `/health` and `/api/health` both return 200 from inside the container.
    - Oversized POST returns 413 through gunicorn (not just the Flask test
      client) — confirms the app-layer guard travels with the image.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| host → container | Untrusted HTTP requests enter container via port 5000 |
| image layers → registry | Image will later ship to ECR; no secrets must be baked in |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-01-03-01 | Elevation of Privilege | container process | mitigate | Non-root uid 10001, USER directive before CMD; readOnlyRootFilesystem-compatible (no runtime writes) |
| T-01-03-02 | Information Disclosure | image layers | mitigate | `.dockerignore` excludes `.env*`, `.git`, `.planning/`, `terraform-infra/`; no secrets in build context |
| T-01-03-03 | Denial of Service | /api/contact body | mitigate | `MAX_CONTENT_LENGTH` enforced by Flask (Plan 01); verified end-to-end in Task 3 |
| T-01-03-04 | Tampering | base image | accept | Pinned to `python:3.12-slim-bookworm` tag; digest pinning deferred per CONTEXT |
</threat_model>

<verification>
All three automated checks above must pass. Clean up test containers in
either success or failure path.
</verification>

<success_criteria>
- `app/portfolio/backend/Dockerfile` exists, multi-stage, pinned base, non-root.
- `app/portfolio/backend/.dockerignore` exists with CONTEXT D-07 entries.
- `docker build` succeeds from a clean clone.
- Running container serves `/health`, `/api/health`, and enforces 413.
</success_criteria>

<output>
After completion, create
`.planning/phases/01-package-local-verify/01-03-SUMMARY.md`.
</output>
