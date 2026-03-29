# Codebase Concerns

**Analysis Date:** 2026-03-28

## Tech Debt

### T1. CORS Wildcard Configuration (Backend)
- **Issue:** FastAPI backend allows all origins with wildcard CORS settings
- **Files:** `app/backend/main.py:18-24`
- **Code:** `allow_origins=["*"]`
- **Impact:** Any website can make requests to the API. Credentials leak, CSRF attacks possible. Should restrict to known frontend domain.
- **Fix approach:** Change to `allow_origins=["https://yedressov.com", "http://localhost:3000"]` for dev/prod respectively.

### T2. Error Handling Without Logging (Frontend)
- **Issue:** Frontend catches backend API errors but only logs to console
- **Files:** `app/frontend/src/server.js:23-28`
- **Code:** `console.error("Backend API unreachable:", err.message)`
- **Impact:** In production, console logs are not captured. No observability into API failures or outages.
- **Fix approach:** Implement structured logging to file or centralized log service (EFK stack already available).

### T3. No Health Check Failure Context (Frontend)
- **Issue:** Health endpoint catches all errors silently with generic "degraded" status
- **Files:** `app/frontend/src/server.js:40-45`
- **Code:** `catch { res.status(503).json({ status: "degraded", service: "portfolio-frontend", backend: "unreachable" })`
- **Impact:** Cannot distinguish network timeout from connection refused from DNS failure. Slow debugging.
- **Fix approach:** Return detailed error reason in response body.

### T4. No Request Timeout Configuration (Frontend)
- **Issue:** Axios calls to backend have no explicit timeout
- **Files:** `app/frontend/src/server.js:21, 34`
- **Code:** `axios.get()` without timeout parameter
- **Impact:** If backend is slow or hanging, requests can hang indefinitely, exhausting connection pools.
- **Fix approach:** Set `axios.defaults.timeout = 5000` or add timeout to individual requests.

### T5. Missing Backend Input Validation
- **Issue:** FastAPI endpoints accept data but Pydantic models don't enforce length/format constraints
- **Files:** `app/backend/main.py:28-63` (all model definitions)
- **Code:** `name: str` without constraints
- **Impact:** Very long strings or malformed data could cause issues. No validation on resume data fields.
- **Fix approach:** Add `Field` constraints: `name: str = Field(max_length=255)`, `email: str = Field(regex=...)`

### T6. No Rate Limiting or API Authentication
- **Issue:** Backend API endpoints are completely open with no authentication or rate limiting
- **Files:** `app/backend/main.py:153-180` (all endpoints)
- **Impact:** Backend can be scraped, abused for DoS. No protection for public endpoints.
- **Fix approach:** Add `slowapi` rate limiter or API key authentication for sensitive endpoints.

### T7. Static Data Hardcoded in Backend (Not Scalable)
- **Issue:** All resume data hardcoded in Python file
- **Files:** `app/backend/main.py:65-149`
- **Impact:** Any resume change requires code redeploy. No version control on data. No separation of concerns.
- **Fix approach:** Move to external data source: JSON files, database, or S3.

## Known Issues

### K1. Missing Values File for Portfolio Helm Chart
- **Issue:** Helm chart has no `values.yaml` file in base directory
- **Files:** `HelmCharts/portfolio/` missing `values.yaml`
- **Impact:** Default values are embedded in HelmRelease spec in `portfolio/base/helmrelease.yaml`. If multiple overlays needed, values duplication occurs.
- **Workaround:** Currently works because single overlay patch overwrites values. Fragile if adding prod overlay.

### K2. Hardcoded AWS Account ID in Image URIs
- **Issue:** Container image URIs hardcoded with AWS account ID
- **Files:** `portfolio/base/helmrelease.yaml:24-25`
- **Code:** `372517046622.dkr.ecr.us-east-1.amazonaws.com/images/...`
- **Impact:** Cannot reuse same manifest in different AWS accounts. Requires manual edit for prod deployment.
- **Workaround:** Use templating or externalize to Kustomization patch.

### K3. Image Tag Pinned to Commit SHA (High Friction for Updates)
- **Issue:** Portfolio images tagged with specific commit SHA `5e83c60`
- **Files:** `portfolio/base/helmrelease.yaml:24-25`
- **Impact:** Manual process to update tags when new commits deployed. No automated image scanning or updates.
- **Workaround:** Works for stability but requires manual workflow to test new versions.

## Security Considerations

### S1. Frontend Environment Variable Exposed (API URL)
- **Issue:** Backend API URL passed as environment variable, visible in pod/deployment specs
- **Files:** `HelmCharts/portfolio/templates/02-frontend.yaml:27-28`
- **Code:** `value: {{ .Values.api.url }}`
- **Risk:** API URL visible in Kubernetes manifests. If API moved, no secret rotation needed but design is fragile.
- **Recommendation:** This is acceptable for public portfolio but production APIs should use hostname resolution (DNS) not env vars.

### S2. No Network Policies for Portfolio Deployment
- **Issue:** Portfolio services (frontend, backend) have no NetworkPolicy restrictions
- **Files:** `portfolio/base/` missing NetworkPolicy manifests
- **Risk:** Any pod in cluster can access portfolio-api service. No network segmentation.
- **Recommendation:** Add NetworkPolicy to restrict frontend→api traffic and deny by default.

### S3. No Pod Security Standards Applied to Portfolio
- **Issue:** Portfolio deployments don't specify pod security contexts (runAsNonRoot, readOnlyRootFilesystem, etc.)
- **Files:** `HelmCharts/portfolio/templates/01-backend.yaml, 02-frontend.yaml` missing securityContext
- **Risk:** Containers run as root by default. If breached, attacker has full container access.
- **Recommendation:** Add explicit security contexts to both backend and frontend deployments.

### S4. No Image Pull Secrets or Private Registry Enforcement
- **Issue:** Portfolio images pulled from public ECR without authentication requirement
- **Files:** `portfolio/base/helmrelease.yaml:24-25`
- **Risk:** Images could be replaced with malicious versions if ECR policies are misconfigured.
- **Recommendation:** Add imagePullSecrets to deployments, enforce ImagePolicies with kyverno.

### S5. Backend Uvicorn Running Without SSL
- **Issue:** Backend exposes plaintext HTTP on port 8000 inside cluster
- **Files:** `app/backend/Dockerfile:13, app/backend/main.py`
- **Code:** `uvicorn ... --host 0.0.0.0 --port 8000` (no --ssl-*)
- **Risk:** Acceptable for internal cluster communication but logs unencrypted. Istio mTLS mitigates but not enforced at app level.
- **Recommendation:** Verify Istio mTLS is enforcing encryption for prod. Add TLS termination at API gateway level.

## Performance Bottlenecks

### P1. Frontend Makes Blocking Backend Call Per Page Load
- **Issue:** Frontend synchronously fetches from backend on every GET /
- **Files:** `app/frontend/src/server.js:19-22`
- **Code:** `const { data } = await axios.get(...)`
- **Problem:** Page load time = backend latency. No caching. If backend slow, users wait.
- **Improvement path:** Add HTTP caching headers, implement frontend-side cache (Redis), or pre-render static HTML.

### P2. Backend Serves Static JSON Data Without Caching
- **Issue:** FastAPI endpoints re-create response objects on every request
- **Files:** `app/backend/main.py:153-180` (all endpoints)
- **Impact:** No caching headers sent. Browser/proxy can't cache. Backend always processes request.
- **Improvement path:** Add `response_model_dump_mode="json"`, set Cache-Control headers, implement CDN caching.

### P3. No Database or Content Delivery
- **Issue:** All portfolio data served from single backend pod(s)
- **Files:** `app/backend/main.py:65-149`
- **Impact:** If backend pod redeployed, users may see temporary stale data or timeouts. No geo-distribution.
- **Improvement path:** Cache data in Redis, use CloudFront CDN, implement stale-while-revalidate.

## Fragile Areas

### F1. Portfolio Application Coupling to Infrastructure
- **Issue:** HelmRelease hardcodes AWS account IDs and image SHAs, making reuse across accounts/environments brittle
- **Files:** `portfolio/base/helmrelease.yaml:24-25`
- **Why fragile:** Cannot move to production without manual edits. No templating layer between app and infra.
- **Safe modification:** Use Kustomization `vars` substitution or external values generation.
- **Test coverage:** No CI validation that manifests render correctly with different values.

### F2. No Integration Tests Between Frontend and Backend
- **Issue:** Frontend and backend developed separately, integrated only at runtime
- **Files:** `app/frontend/src/server.js` has no tests
- **Why fragile:** API contract not validated. Frontend could request undefined endpoints. Backend could change response shape.
- **Safe modification:** Add contract tests or API schema validation (OpenAPI).
- **Test coverage:** Zero tests on frontend server code.

### F3. Kubernetes Configuration Scattered Across Multiple Locations
- **Issue:** Portfolio config exists in three places: `HelmCharts/portfolio/`, `portfolio/base/`, and `clusters/dev-projectx/portfolio.yaml`
- **Files:** Multiple locations for same application
- **Why fragile:** Single source of truth unclear. Changes in one place may not propagate.
- **Safe modification:** Centralize in `portfolio/` directory, use single HelmRelease+Kustomization pattern.
- **Test coverage:** No automated validation that Kustomization produces expected manifests.

## Scaling Limits

### SC1. Backend Hardcoded with 2 Replicas
- **Issue:** Portfolio HelmRelease specifies `replicas: 2` without HPA or metrics-based scaling
- **Files:** `portfolio/base/helmrelease.yaml:20-21`
- **Impact:** Cannot auto-scale based on traffic. Manual intervention needed if load increases.
- **Scaling path:** Add HorizontalPodAutoscaler targeting CPU/memory metrics.

### SC2. No Persistence or StatefulSet Consideration
- **Issue:** Both frontend and backend are Deployments (stateless) with minimal resources
- **Files:** `HelmCharts/portfolio/templates/01-backend.yaml:11, 02-frontend.yaml:11`
- **Impact:** If future features add local storage or session state, architecture breaks. Needs refactor.
- **Scaling path:** Design stateless from start, use external session store if needed.

## Dependencies at Risk

### D1. Outdated Pydantic Version
- **Issue:** `pydantic==2.9.0` is pinned but not latest
- **Files:** `app/backend/requirements.txt:3`
- **Risk:** Minor security fixes may be missing. `2.9.0` released ~6 months ago, newer patches available.
- **Migration plan:** Update to `pydantic==2.11.0+` and test backward compatibility (should be safe for minor bump).

### D2. Express.js Version Pinned to ^4.21.0
- **Issue:** Package.json uses caret range, not exact version
- **Files:** `app/frontend/package.json:11`
- **Code:** `"express": "^4.21.0"`
- **Risk:** package-lock.json should pin exact version, but if lock is regenerated, newer Express versions installed. No reproducibility guarantee.
- **Recommendation:** Use exact versions: `"express": "4.21.0"` in package.json.

### D3. Node.js 20-alpine Not Pinned to Exact Version
- **Issue:** Dockerfile uses `FROM node:20-alpine` without patch version
- **Files:** `app/frontend/Dockerfile:2`
- **Risk:** If Node.js 20.x gets security update, next build gets different runtime. Non-reproducible builds.
- **Migration plan:** Pin to `node:20.15.1-alpine` or use pinned base image digest.

### D4. Python 3.12-slim Not Pinned to Patch Version
- **Issue:** Backend Dockerfile uses `FROM python:3.12-slim` without patch version
- **Files:** `app/backend/Dockerfile:2`
- **Risk:** Python security updates auto-applied on rebuild, but versions not reproducible.
- **Migration plan:** Pin to `python:3.12.3-slim` or use digest-based references.

## Missing Critical Features

### M1. No Application Metrics or Observability
- **Issue:** Backend and frontend don't expose Prometheus metrics
- **Files:** `app/backend/main.py, app/frontend/src/server.js`
- **Impact:** Cannot track API latency, error rates, or business metrics. Cluster has monitoring stack but app doesn't integrate.
- **Blocks:** Cannot effectively debug performance issues in production.

### M2. No Structured Logging
- **Issue:** Both backend and frontend use basic console.log / print without structured logging
- **Files:** `app/backend/main.py:24, app/frontend/src/server.js:24`
- **Impact:** EFK stack deployed but app logs not machine-parseable. Cannot search for errors in production logs.
- **Blocks:** Difficult incident investigation.

### M3. No Graceful Shutdown Handling
- **Issue:** Applications don't handle SIGTERM signal for graceful pod termination
- **Files:** `app/frontend/src/server.js:49-52 (no shutdown handler)`
- **Impact:** During rolling updates, in-flight requests may be dropped without completion.
- **Blocks:** Reliable zero-downtime deployments.

### M4. No Readiness/Liveness Differentiation
- **Issue:** Kubernetes probes both use same /health endpoint, no distinction between ready and alive
- **Files:** `HelmCharts/portfolio/templates/01-backend.yaml:33-44, 02-frontend.yaml:38-49`
- **Impact:** Pod could be removed from load balancer (not ready) even if it's healthy, causing unnecessary disruptions.
- **Blocks:** Proper pod lifecycle management.

## Test Coverage Gaps

### TC1. No Unit Tests in Backend
- **Issue:** FastAPI backend has no test file or test coverage
- **Files:** `app/backend/` has only `main.py` (no `test_*.py`)
- **What's not tested:** API response format, data structure validation, error handling
- **Files affected:** `app/backend/main.py` (entire file untested)
- **Risk:** Data structure changes break frontend silently. Endpoint changes go undetected.
- **Priority:** Medium (resume data is static, but refactoring risky)

### TC2. No Unit Tests in Frontend Server
- **Issue:** Express server code has no tests
- **Files:** `app/frontend/` has only `src/server.js` (no `test_*.js`)
- **What's not tested:** Error handling, health check response, backend unavailability scenarios
- **Files affected:** `app/frontend/src/server.js` (entire file untested)
- **Risk:** Health check could silently fail to connect to backend. Error pages not validated.
- **Priority:** Medium

### TC3. No Integration Tests Between Services
- **Issue:** No test that validates frontend can call backend successfully
- **Files:** No `integration/` or `e2e/` test directory
- **What's not tested:** Request/response contract, latency, error scenarios
- **Risk:** Breaking changes in one service not caught until deployed.
- **Priority:** High for multi-service applications

### TC4. No Helm Chart Validation
- **Issue:** No `helm lint` or `helm template` tests in CI/CD
- **Files:** `.github/workflows/` has no chart validation step
- **What's not tested:** Chart syntax, template rendering, value validation
- **Risk:** Invalid manifests deploy to cluster without warning.
- **Priority:** High

### TC5. No Container Image Scanning
- **Issue:** No vulnerability scanning before image push
- **Files:** `.github/workflows/image.yaml` exists but content not checked
- **What's not tested:** Dockerfile base image vulnerabilities, dependency vulnerabilities
- **Risk:** Vulnerable images pushed to ECR undetected.
- **Priority:** High

---

*Concerns audit: 2026-03-28*
