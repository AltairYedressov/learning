# Codebase Concerns

**Analysis Date:** 2026-04-15

## Tech Debt

**Duplicate Application Code (app/ vs app/portfolio/):**
- Issue: Two separate implementations of the portfolio backend exist in parallel
  - `app/backend/` uses FastAPI with Pydantic models and rate limiting via slowapi
  - `app/portfolio/backend/` uses Flask with an email contact form service
  - `app/frontend/` uses Express + axios
  - `app/portfolio/frontend/` uses Express with helmet + http-proxy-middleware
- Files: 
  - `app/backend/main.py` (223 lines, FastAPI with hardened security)
  - `app/portfolio/backend/app.py` (email service, Flask)
  - `app/frontend/src/server.js` (minimal Express server)
  - `app/portfolio/frontend/server.js` (more robust with proxy + helmet)
- Impact: Maintenance burden, inconsistent patterns, unclear which is deployed to production. Tests only cover `app/backend/` so `app/portfolio/` is unvalidated
- Fix approach: Consolidate to single implementation. Choose whether to keep FastAPI or Flask backend; choose whether to keep simple Express or helmeted + proxied version

**Missing Error Handling in Frontend Server:**
- Issue: `app/frontend/src/server.js` line 40 uses silent catch (`catch { }`) for health check failures, masking errors
- Files: `app/frontend/src/server.js` line 40-46
- Impact: Silent failures make debugging difficult; operators won't know health endpoint is broken
- Fix approach: Log errors explicitly in catch block, don't suppress them

**Hardcoded CORS Origins in Backend:**
- Issue: Production CORS origins hardcoded in code rather than environment-driven
- Files: `app/backend/main.py` line 50 — `allow_origins=["https://yedressov.com", "http://localhost:3000"]`
- Impact: Code change required to add new origins; localhost allowed in production config
- Fix approach: Load CORS origins from environment variable (e.g., `ALLOWED_ORIGINS`)

**Email Service in Wrong Repository:**
- Issue: Contact form email service (`app/portfolio/backend/app.py`) sits in application repo but has no integration point
- Files: `app/portfolio/backend/app.py` (Flask service with SMTP configuration)
- Impact: Feature incomplete; blocking ingress traffic, no route in main VirtualService
- Fix approach: Either finish implementation (add email endpoint, test it, deploy) or delete if not needed

## Fragile Areas

**Frontend-Backend Coupling via Implicit Contract:**
- Issue: Frontend assumes backend `/api/all` endpoint exists and returns specific JSON schema. No validation or type safety
- Files: 
  - `app/frontend/src/server.js` line 21 — assumes `data` contains `profile`, `skills`, `experience`, `certifications`, `projects`
  - `app/backend/main.py` line 213-222 — defines schema
- Why fragile: Schema changes in backend break frontend at runtime; no TypeScript interfaces or schema validation
- Safe modification: 
  1. Add TypeScript to frontend (or use JSDoc type checking)
  2. Generate frontend types from backend models
  3. Add API contract tests that validate response shape

**Database Connection Not Tested:**
- Issue: RDS database created via Terraform but application doesn't use it. No integration tests verify database connection
- Files: `terraform-infra/database/main.tf` (RDS instance provisioned); `app/backend/main.py` (hardcoded data, no DB client)
- Impact: Database misconfiguration won't be caught. Cost waste on unused database. Unclear if failover/DR actually works
- Test coverage: Zero — no tests attempt database operations

**Istio Gateway Protocol Mismatch:**
- Issue: Gateway manifest defines HTTPS port (8443) with `protocol: HTTP` instead of `HTTPS`
- Files: `platform-tools/istio/istio-ingress/base/gateway.yaml` line 22
- Impact: TLS termination may fail; traffic might not be encrypted as intended
- Fix approach: Change `protocol: HTTP` to `protocol: HTTPS` and verify certificate is configured

## Test Coverage Gaps

**No Integration Tests:**
- What's not tested: 
  - Frontend → Backend API communication (only unit tests for API exist)
  - Rate limiting across multiple requests
  - CORS with actual HTTP requests (unit tests use TestClient)
  - Health check endpoints from a client perspective
- Files: `app/backend/tests/test_security.py` (security-focused only)
- Risk: API behavior changes could break frontend in production

**No End-to-End Tests:**
- What's not tested:
  - Full user journey (load page, fetch all data, verify rendered content)
  - Navigation between routes
  - Error page rendering when backend is down
- Files: No e2e test framework detected
- Risk: Silent failures in rendering, broken links undetected

**No Database Tests:**
- What's not tested:
  - Database connectivity
  - RDS failover behavior
  - Backup/restore functionality
  - DR replica sync
- Files: `terraform-infra/database/main.tf` provisioned but no integration tests
- Risk: Database disaster recovery is untested and may not work

**No Helm Chart Tests:**
- What's not tested:
  - Helm template rendering
  - ConfigMap/Secret injection into pods
  - Service discovery names correct
  - Security context enforcement (runAsNonRoot, readOnlyRootFilesystem)
- Files: `HelmCharts/portfolio/` deployed via Flux but no helm test or lint checks
- Risk: Invalid Kubernetes manifests only detected after deployment

**No Load Testing:**
- What's not tested:
  - Rate limiter effectiveness under sustained load
  - Resource limits actually prevent OOMKill
  - Horizontal scaling behavior
- Files: Rate limiter configured in `app/backend/main.py` but untested at scale
- Risk: SLA failures under real traffic

## Security Considerations

**Localhost CORS Allowed in Production:**
- Risk: If frontend is ever served from localhost in production, unwanted origin could exploit it
- Files: `app/backend/main.py` line 50 — `allow_origins=["https://yedressov.com", "http://localhost:3000"]`
- Current mitigation: Application is private/non-sensitive
- Recommendations: 
  - Remove localhost from production CORS config
  - Use environment-based origin list
  - Add validation that production environment doesn't contain localhost

**Unencrypted Database in Dev:**
- Risk: Resume data in plaintext if database is compromised
- Files: `terraform-infra/root/dev/database/` — encryption disabled for cost savings
- Current mitigation: Data is non-sensitive (public resume)
- Recommendations: Enable encryption for consistency with prod, even if data is public

**Missing HTTPS Enforcement in Frontend Gateway:**
- Risk: TLS mismatch if gateway protocol is wrong
- Files: `platform-tools/istio/istio-ingress/base/gateway.yaml` line 22
- Current mitigation: AWS NLB requires TLS; Istio fallback should still work
- Recommendations: Fix gateway protocol to explicitly use HTTPS

**GitHub Token Passed via Terraform Variable:**
- Risk: Token is sensitive and marked `sensitive = true`, but if accidentally logged, exposure occurs
- Files: `terraform-infra/eks-cluster/variables.tf` line 34-37
- Current mitigation: Terraform marks it sensitive; GitHub Actions provides via OIDC
- Recommendations: Verify logs are scrubbed; audit GitHub token permissions regularly

## Scaling Limits

**Frontend Resource Limits May Bottleneck:**
- Current capacity: 
  - CPU: 100m request, 250m limit
  - Memory: 128Mi request, 256Mi limit
- Limit: Each request to fetch data involves axios call to backend. Synchronous rendering could block under load
- Scaling path: 
  1. Add HTTP caching headers to backend responses
  2. Implement request pooling in frontend
  3. Use Node cluster mode or vertical scaling

**Rate Limiter Uses In-Memory Store:**
- Current capacity: Limited by pod memory (256Mi)
- Limit: Scales to single pod; if frontend replicas = 2, each has separate rate limit store
- Scaling path: 
  1. Move rate limiting to Redis (shared across pods)
  2. Or use Envoy proxy-level rate limiting (Istio)

**Backend Hardcoded Data:**
- Current capacity: All data in `app/backend/main.py` globals (no DB)
- Limit: Scales only by adding replicas (all serve same hardcoded data)
- Scaling path: Connect to RDS database and load data at startup

## Performance Bottlenecks

**Frontend Makes Synchronous Backend Call Per Request:**
- Problem: `app/frontend/src/server.js` line 21 calls `axios.get(`${API_URL}/api/all`)` on every GET /
- Files: `app/frontend/src/server.js` line 19-29
- Cause: No caching; every page load fetches entire resume from API
- Improvement path:
  1. Cache response for 1 hour (resume data is static)
  2. Use Redis or Node memory cache
  3. Or pre-render to static HTML at build time

**No HTTP Caching Headers:**
- Problem: Backend doesn't set Cache-Control, Etag, or Last-Modified headers
- Files: `app/backend/main.py` — no caching directives in endpoint responses
- Cause: FastAPI returns raw Pydantic models without response wrapping
- Improvement path:
  1. Add `response.headers["Cache-Control"] = "public, max-age=3600"`
  2. Or use CDN (Cloudflare) to cache at edge

## Known Bugs

**Silent Health Check Failure:**
- Symptoms: Frontend health endpoint returns degraded status but error is not logged
- Files: `app/frontend/src/server.js` line 40 — `catch { }` swallows error
- Trigger: Trigger a backend crash or network partition while frontend is running
- Workaround: Manually check backend separately; frontend health endpoint still works but misleading

**Istio Gateway Protocol Type May Prevent TLS Termination:**
- Symptoms: HTTPS traffic may fail or downgrade to HTTP if gateway protocol is mismatched
- Files: `platform-tools/istio/istio-ingress/base/gateway.yaml` line 22
- Trigger: Try accessing https://yedressov.com; inspect TLS negotiation logs
- Workaround: None; must fix the gateway manifest

## Dependencies at Risk

**No Version Pinning in requirements.txt:**
- Risk: `pip install -r requirements.txt` could pull incompatible minor versions
- Files: `app/backend/requirements.txt` — versions pinned (good) but no upper bounds
- Impact: Security patches could introduce breaking changes
- Migration plan: Add `pip-tools` to lock dependencies with sub-dependencies

**axios Vulnerable to MiM with Hardcoded localhost:**
- Risk: If frontend environment variable not set, axios connects to http://localhost:8000 (unencrypted)
- Files: `app/frontend/src/server.js` line 12 — `const API_URL = process.env.API_URL || "http://localhost:8000"`
- Impact: Development default is fine, but if deployed without API_URL env var, connection is insecure
- Migration plan: Fail fast if API_URL not set in production

## Missing Critical Features

**No Monitoring/Alerting for Application Metrics:**
- Problem: Backend has no Prometheus metrics endpoint; frontend has no performance instrumentation
- Blocks: Can't detect slow API responses, high error rates, or capacity issues without logs
- Files: `app/backend/main.py` and `app/frontend/src/server.js` — no metrics export
- Fix approach:
  1. Add `prometheus-client` to FastAPI backend
  2. Export request latency, error count, rate limit hits
  3. Configure Prometheus scrape job
  4. Add Grafana dashboard and alerts

**No Structured Logging:**
- Problem: Logs are console.log() and print() statements; not queryable or aggregatable
- Blocks: EFK stack is deployed but application logs are unstructured
- Files: `app/backend/main.py` line 190 uses plain `datetime.datetime.utcnow()` in response (not logged)
- Fix approach:
  1. Use structured logging library (Python: `logging` module with JSON formatter; Node: `winston`)
  2. Emit JSON logs to stdout
  3. EFK will automatically index and parse

**No API Versioning:**
- Problem: Frontend tightly coupled to single `/api/all` endpoint; no v2 migration path
- Blocks: Can't iterate on API schema without breaking frontend
- Fix approach:
  1. Version API endpoints: `/api/v1/all`, `/api/v2/all`
  2. Support multiple versions during migration
  3. Document deprecation timeline

---

*Concerns audit: 2026-04-15*
