---
phase: 01-package-local-verify
plan: 05
type: execute
wave: 3
depends_on: [01, 02, 03, 04]
files_modified:
  - app/portfolio/README.md
autonomous: false
requirements: [PKG-03]
tags: [docs, verification, local]

must_haves:
  truths:
    - "A README in app/portfolio/ documents how to build, run, and verify both images locally."
    - "Following the README end-to-end proves: both images build, both /health endpoints return 200, /api/contact enforces 413 and 429 before SMTP, and the frontend proxies /api/health through to the backend."
    - "The verification protocol uses only env vars listed in CONTEXT D-06 — no secrets required (SMTP_USER/PASS unset → dev-mode log)."
  artifacts:
    - path: "app/portfolio/README.md"
      provides: "Local build + boot + verify protocol"
      contains: "docker build"
      contains_health: "/health"
      contains_413: "413"
      contains_429: "429"
  key_links:
    - from: "README protocol"
      to: "CONTEXT D-08 verification steps"
      via: "literal mapping of curl commands"
      pattern: "protocol-mirror"
---

<objective>
Document the Phase 1 local-verify protocol and run it end-to-end to prove
PKG-03 ("both Dockerfiles pass a local docker build and container boot test").

Purpose: Produce the README that future developers (and Phase 2 CI) use as
the canonical reproduction recipe, and capture a single checkpoint where the
user confirms the full stack works locally.

Output: New `app/portfolio/README.md` + a human-verify checkpoint on the
happy-path contact-form proxy flow.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/ROADMAP.md
@.planning/REQUIREMENTS.md
@.planning/phases/01-package-local-verify/01-CONTEXT.md
@.planning/phases/01-package-local-verify/01-01-SUMMARY.md
@.planning/phases/01-package-local-verify/01-02-SUMMARY.md
@.planning/phases/01-package-local-verify/01-03-SUMMARY.md
@.planning/phases/01-package-local-verify/01-04-SUMMARY.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Write app/portfolio/README.md with local-verify protocol</name>
  <files>app/portfolio/README.md</files>
  <action>
    Create `app/portfolio/README.md` with the following structure
    (CONTEXT D-08 mapped literally — do NOT paraphrase away the guardrail checks):

    ```markdown
    # Portfolio v2 — Local Build & Verify

    Two services live under this tree:

    | Service        | Path                         | Port | Image tag suggestion |
    |----------------|------------------------------|------|----------------------|
    | portfolio-api  | `app/portfolio/backend/`     | 5000 | `portfolio-api:dev`  |
    | portfolio-web  | `app/portfolio/frontend/`    | 3000 | `portfolio-web:dev`  |

    ## 1. Build

    From repo root:

    ```bash
    docker build -t portfolio-api:dev app/portfolio/backend
    docker build -t portfolio-web:dev app/portfolio/frontend
    ```

    Both builds must succeed from a clean clone (no `.env`, no
    `node_modules`, no `__pycache__` on disk).

    ## 2. Run

    Start the backend first (leave SMTP_USER/PASS unset to exercise
    dev-mode log instead of sending real email):

    ```bash
    docker run -d --name portfolio-api -p 5000:5000 \
      -e BACKEND_PORT=5000 \
      -e ALLOWED_ORIGINS=http://localhost:3000 \
      -e RATE_LIMIT=5 \
      -e RATE_WINDOW_MINUTES=15 \
      -e MAX_BODY_BYTES=16384 \
      portfolio-api:dev
    ```

    Then start the frontend pointing at it:

    ```bash
    docker run -d --name portfolio-web -p 3000:3000 \
      -e PORT=3000 \
      -e BACKEND_URL=http://host.docker.internal:5000 \
      -e NODE_ENV=production \
      portfolio-web:dev
    ```

    (On Linux substitute `--network=host` or a shared user-defined bridge
    for `host.docker.internal`.)

    ## 3. Verify

    ### 3.1 Health endpoints (APP-01, APP-02)

    ```bash
    curl -fsS http://localhost:3000/health    # → 200 {"status":"ok"}  (frontend-local)
    curl -fsS http://localhost:5000/health    # → 200 {"status":"ok"}  (backend-bare)
    curl -fsS http://localhost:5000/api/health # → 200 (existing endpoint)
    curl -fsS http://localhost:3000/api/health # → 200 (proxied through frontend)
    ```

    ### 3.2 Body-size cap (SEC-07, APP-05)

    With `MAX_BODY_BYTES=16384` a 20 KB body must be rejected:

    ```bash
    python3 -c "import json,sys; sys.stdout.write(json.dumps({'message':'x'*20000}))" > /tmp/big.json
    curl -s -o /dev/stderr -w 'HTTP %{http_code}\n' \
         -X POST -H 'Content-Type: application/json' \
         --data @/tmp/big.json http://localhost:5000/api/contact
    # Expected: HTTP 413, body {"success":false,"error":"Payload too large."}
    ```

    ### 3.3 Rate limit (APP-05)

    Send six valid submissions within the window — the 6th must 429:

    ```bash
    for i in 1 2 3 4 5 6; do
      curl -s -o /dev/null -w "req $i → %{http_code}\n" \
           -X POST -H 'Content-Type: application/json' \
           -d '{"name":"Al","email":"a@b.co","subject":"hello there","message":"this is a test message body"}' \
           http://localhost:5000/api/contact
    done
    # Expected: reqs 1..5 → 200, req 6 → 429
    ```

    (Reset by restarting the container; state is in-memory per CONTEXT D-04.)

    ### 3.4 Frontend proxy happy path (APP-04)

    ```bash
    curl -s -X POST -H 'Content-Type: application/json' \
         -d '{"name":"Al","email":"a@b.co","subject":"via proxy","message":"proxied from frontend ok"}' \
         http://localhost:3000/api/contact
    # Expected: 200 {"success":true,...}  (SMTP dev-mode → logged only)
    ```

    ## 4. Cleanup

    ```bash
    docker rm -f portfolio-api portfolio-web
    ```

    ## 5. Environment variable reference

    See CONTEXT D-06 for the locked variable list and defaults. Secrets
    (SMTP_USER / SMTP_PASS) are NOT set in Phase 1 — they arrive via
    Sealed Secret in Phase 2.
    ```

    Do NOT include real SMTP credentials in the README even as examples.
  </action>
  <verify>
    <automated>test -f app/portfolio/README.md &amp;&amp; \
grep -q 'docker build -t portfolio-api' app/portfolio/README.md &amp;&amp; \
grep -q '/health' app/portfolio/README.md &amp;&amp; \
grep -q '413' app/portfolio/README.md &amp;&amp; \
grep -q '429' app/portfolio/README.md &amp;&amp; \
grep -q 'MAX_BODY_BYTES' app/portfolio/README.md &amp;&amp; \
echo "OK: README covers build, health, 413, 429, env vars"</automated>
  </verify>
  <done>
    - `app/portfolio/README.md` exists and contains all four verification
      sections (health, 413, 429, proxy).
    - No credentials in the file.
    - Filename-based discovery works (`ls app/portfolio/README.md`).
  </done>
</task>

<task type="auto">
  <name>Task 2: Execute the README protocol end-to-end</name>
  <files>app/portfolio/README.md</files>
  <action>
    Run the README protocol verbatim from the repo root. Collect the output
    of each curl command. If any check diverges from the expected response,
    stop and report — do NOT proceed to the checkpoint.

    Clean up both containers at the end regardless of outcome.
  </action>
  <verify>
    <automated>set -e
docker rm -f portfolio-api portfolio-web 2&gt;/dev/null || true
docker build -t portfolio-api:dev app/portfolio/backend
docker build -t portfolio-web:dev app/portfolio/frontend
docker run -d --name portfolio-api -p 5000:5000 \
  -e BACKEND_PORT=5000 -e ALLOWED_ORIGINS=http://localhost:3000 \
  -e RATE_LIMIT=5 -e RATE_WINDOW_MINUTES=15 -e MAX_BODY_BYTES=16384 \
  portfolio-api:dev
# Linux-friendly backend URL for the frontend:
BACKEND_URL_LINUX=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' portfolio-api)
docker run -d --name portfolio-web -p 3000:3000 \
  -e PORT=3000 -e BACKEND_URL="http://${BACKEND_URL_LINUX}:5000" -e NODE_ENV=production \
  portfolio-web:dev
sleep 3
curl -fsS http://localhost:3000/health | grep -q '"status":"ok"'
curl -fsS http://localhost:5000/health | grep -q '"status":"ok"'
curl -fsS http://localhost:5000/api/health | grep -q '"status":"ok"'
curl -fsS http://localhost:3000/api/health | grep -q '"status":"ok"'
python3 -c "import json,sys; sys.stdout.write(json.dumps({'message':'x'*20000}))" &gt; /tmp/big.json
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' --data @/tmp/big.json http://localhost:5000/api/contact)
test "$CODE" = "413"
LAST=200
for i in 1 2 3 4 5 6; do
  LAST=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
    -d '{"name":"Al","email":"a@b.co","subject":"hello there","message":"this is a test message body"}' \
    http://localhost:5000/api/contact)
done
test "$LAST" = "429"
docker rm -f portfolio-api portfolio-web
echo "OK: full local-verify protocol passed"</automated>
  </verify>
  <done>
    - Full protocol passes: both builds green, four 200s on health checks,
      413 on oversized body, 429 on 6th submission.
    - Containers removed on success.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 3: Human confirmation of local verify</name>
  <what-built>
    Phase 1 is functionally complete:
    - Backend app.py has bare /health, MAX_CONTENT_LENGTH from env, 413 handler.
    - Frontend server.js has a local /health ordered correctly.
    - Both Dockerfiles build non-root, pinned-base images.
    - README.md documents the reproduction protocol.
    - Task 2 above has just run the protocol end-to-end with all assertions passing.
  </what-built>
  <how-to-verify>
    1. Inspect `app/portfolio/README.md` — skim the four Verify sections.
    2. Optionally re-run the Task 2 automated block yourself from a clean
       terminal and confirm it prints `OK: full local-verify protocol passed`.
    3. Confirm no new files were created outside `app/portfolio/` except
       SUMMARY files under `.planning/phases/01-package-local-verify/`.
    4. Confirm Plan 01..04 SUMMARYs exist.
  </how-to-verify>
  <resume-signal>Type "approved" to mark Phase 1 done, or describe any gap.</resume-signal>
</task>

</tasks>

<verification>
The Task 2 shell block IS the verification. On success, the checkpoint
finalizes human sign-off.
</verification>

<success_criteria>
- README exists and matches CONTEXT D-08.
- End-to-end protocol passes without manual intervention.
- Human approval recorded.
</success_criteria>

<output>
After completion, create
`.planning/phases/01-package-local-verify/01-05-SUMMARY.md` including the
full stdout of Task 2's verify block.
</output>
