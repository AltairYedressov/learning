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

See `.planning/phases/01-package-local-verify/01-CONTEXT.md` section D-06
for the locked variable list and defaults. Secrets (SMTP_USER / SMTP_PASS)
are NOT set in Phase 1 — they arrive via Sealed Secret in Phase 2.
