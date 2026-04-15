---
phase: 01-package-local-verify
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - app/portfolio/backend/app.py
autonomous: true
requirements: [APP-01, APP-03, APP-05, SEC-07]
tags: [flask, backend, health, rate-limit, body-cap]

must_haves:
  truths:
    - "GET /health returns 200 with JSON {status: ok} without requiring auth or SMTP."
    - "GET /api/health continues to return 200 (existing behavior preserved)."
    - "POST /api/contact with body > MAX_BODY_BYTES (default 16384) returns HTTP 413 with JSON {success:false,error:'Payload too large.'} BEFORE validation/SMTP."
    - "6th POST /api/contact from same IP within RATE_WINDOW_MINUTES returns 429."
    - "All config (SMTP_*, RECIPIENT_EMAIL, ALLOWED_ORIGINS, RATE_LIMIT, RATE_WINDOW_MINUTES, MAX_BODY_BYTES, BACKEND_PORT) read from env with documented defaults."
  artifacts:
    - path: "app/portfolio/backend/app.py"
      provides: "Flask app with bare /health route, MAX_CONTENT_LENGTH, 413 handler"
      contains: '@app.route("/health"'
      contains_also: 'MAX_CONTENT_LENGTH'
      contains_413: '@app.errorhandler(413)'
  key_links:
    - from: "Flask config MAX_CONTENT_LENGTH"
      to: "os.getenv('MAX_BODY_BYTES', '16384')"
      via: "app.config assignment at module load"
      pattern: "MAX_CONTENT_LENGTH.*MAX_BODY_BYTES"
    - from: "413 error handler"
      to: "JSON error response"
      via: "@app.errorhandler(413)"
      pattern: "errorhandler\\(413\\)"
---

<objective>
Harden the existing Flask app so that it satisfies Phase 1 success criteria #2
(health endpoint) and #3 (413 + rate-limit before SMTP) from ROADMAP.md.

Purpose: Requirements APP-01, APP-03, APP-05, SEC-07 — health endpoint,
env-driven config, ordered contact-form guards, body-size rejection with 413.

Output: Modified `app/portfolio/backend/app.py` with a bare `/health` route,
Flask-native MAX_CONTENT_LENGTH enforcement, and an explicit 413 error handler.
No Dockerfile work in this plan — packaging happens in Plan 03.
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
@app/portfolio/backend/app.py
@app/portfolio/backend/requirements.txt

<interfaces>
<!-- Existing Flask app exposes: -->
<!-- - app = Flask(__name__)                                  (module-level) -->
<!-- - CORS(app, origins=os.getenv("ALLOWED_ORIGINS",...))    (already wired) -->
<!-- - @app.route("/api/health", GET)  -> {"status":"ok","timestamp":...}     -->
<!-- - @app.route("/api/contact", POST) -> rate-limit + validate + SMTP       -->
<!-- - _is_rate_limited(ip: str) -> bool                                       -->
<!-- - _validate_payload(data: dict) -> list[str]                              -->
<!-- - RATE_LIMIT, RATE_WINDOW read from env (names differ from REQ wording:  -->
<!--   REQ APP-03 lists MAX_BODY_SIZE; CONTEXT D-06 locks MAX_BODY_BYTES —    -->
<!--   honor CONTEXT: env var name is MAX_BODY_BYTES.)                         -->
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add bare /health route and MAX_CONTENT_LENGTH with 413 handler</name>
  <files>app/portfolio/backend/app.py</files>
  <behavior>
    - GET /health → 200, JSON {"status":"ok"} (no timestamp required, but OK if included).
    - GET /api/health → 200 (unchanged — regression check).
    - POST /api/contact with Content-Length > MAX_BODY_BYTES → 413, JSON {"success":false,"error":"Payload too large."}.
    - 413 handler fires BEFORE _is_rate_limited and BEFORE _validate_payload (Flask's MAX_CONTENT_LENGTH check is enforced at request parsing, which is before any route handler body runs).
    - Default MAX_BODY_BYTES = 16384 when env unset; overridable via env.
  </behavior>
  <action>
    Edit `app/portfolio/backend/app.py`:

    1. After `app = Flask(__name__)` (currently line 21) and before the CORS
       call, add:
       ```python
       app.config["MAX_CONTENT_LENGTH"] = int(os.getenv("MAX_BODY_BYTES", 16384))
       ```
       Per CONTEXT D-06, the env var name is `MAX_BODY_BYTES` (not `MAX_BODY_SIZE`
       as REQ APP-03 suggests — CONTEXT is authoritative).

    2. Add a bare `/health` route ABOVE the existing `/api/health` route
       (around line 138). Per CONTEXT D-02 this is additive — do NOT remove
       `/api/health`:
       ```python
       @app.route("/health", methods=["GET"])
       def health_bare():
           return jsonify({"status": "ok"}), 200
       ```

    3. Add a 413 error handler near the other route handlers (before the
       `if __name__ == "__main__":` guard):
       ```python
       @app.errorhandler(413)
       def payload_too_large(_err):
           return jsonify({"success": False, "error": "Payload too large."}), 413
       ```

    4. Do NOT touch the existing rate-limit or validation logic — it already
       satisfies APP-05. Do NOT rename env vars used today (ALLOWED_ORIGINS,
       RATE_LIMIT, RATE_WINDOW_MINUTES remain as-is).

    5. Do NOT add a separate test file — verification below uses ad-hoc
       Python + Flask test client invocations. A dedicated test suite is
       deferred (out of scope for Phase 1).
  </action>
  <verify>
    <automated>cd app/portfolio/backend &amp;&amp; python -c "
import os
os.environ['MAX_BODY_BYTES']='100'
from app import app
c = app.test_client()
assert c.get('/health').status_code == 200, 'bare /health failed'
assert c.get('/api/health').status_code == 200, '/api/health regression'
r = c.post('/api/contact', data='x'*500, content_type='application/json')
assert r.status_code == 413, f'expected 413 got {r.status_code}'
assert r.get_json().get('error') == 'Payload too large.', 'wrong 413 body'
print('OK: health + 413 handler wired correctly')
"</automated>
  </verify>
  <done>
    - `/health` returns 200 with `{"status":"ok"}`.
    - `/api/health` still returns 200 (regression clean).
    - Oversized POST to `/api/contact` returns 413 with the exact JSON body specified in CONTEXT D-03.
    - `MAX_CONTENT_LENGTH` is set from `MAX_BODY_BYTES` env var with default 16384.
  </done>
</task>

<task type="auto">
  <name>Task 2: Verify rate-limit ordering with respect to body-cap</name>
  <files>app/portfolio/backend/app.py</files>
  <action>
    No code changes expected — this task confirms that Flask's built-in
    MAX_CONTENT_LENGTH guard fires BEFORE the route handler (and therefore
    before `_is_rate_limited` and `_send_email`). This is the Flask framework
    behavior but must be explicitly verified to satisfy SEC-07 + APP-05
    ("enforces body size cap before attempting SMTP send").

    If the verification below fails (unlikely), the fix is to add a
    `@app.before_request` hook that inspects `request.content_length` and
    aborts(413) — but attempt this only if the default framework behavior
    fails the test.
  </action>
  <verify>
    <automated>cd app/portfolio/backend &amp;&amp; python -c "
import os
os.environ['MAX_BODY_BYTES']='50'
os.environ['RATE_LIMIT']='1'
from app import app
c = app.test_client()
# First: oversized body should 413, NOT consume a rate-limit slot.
for _ in range(3):
    r = c.post('/api/contact', data='x'*200, content_type='application/json',
               headers={'X-Forwarded-For': '9.9.9.9'})
    assert r.status_code == 413, f'expected 413 got {r.status_code}'
# Then: a valid-sized but invalid-payload request should 400 (validation),
# proving the rate-limit counter was never decremented by 413s.
r = c.post('/api/contact', json={}, headers={'X-Forwarded-For':'9.9.9.9'})
assert r.status_code in (400, 429), f'unexpected {r.status_code}'
print('OK: 413 fires before rate-limit / validation / SMTP')
"</automated>
  </verify>
  <done>
    - 413 responses do not consume rate-limit budget (framework guards run first).
    - Confirms SEC-07 ordering requirement: body-size rejection happens before SMTP.
  </done>
</task>

</tasks>

<verification>
Run both verification scripts above from a clean venv with `flask`,
`flask-cors`, `python-dotenv` installed (via
`pip install -r app/portfolio/backend/requirements.txt`). Both must print
`OK: ...` and exit 0.
</verification>

<success_criteria>
- `app/portfolio/backend/app.py` contains `@app.route("/health"`,
  `MAX_CONTENT_LENGTH`, and `@app.errorhandler(413)`.
- Both verification scripts pass.
- No existing behavior regressed (`/api/health`, `/api/contact` happy path
  still work).
- No Dockerfile changes in this plan.
</success_criteria>

<output>
After completion, create
`.planning/phases/01-package-local-verify/01-01-SUMMARY.md` documenting:
- Lines changed in app.py (with excerpts of the three new blocks).
- Verification command outputs.
- Any deviations from CONTEXT (expected: none).
</output>
