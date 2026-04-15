# Coding Conventions

**Analysis Date:** 2026-04-15

This brownfield AWS EKS project spans four primary languages (JavaScript, Python, HCL/Terraform, YAML) plus shell. No automated linters or formatters are configured in the repo for application code; conventions below are derived from observed patterns in the source tree.

## Naming Patterns

### Files
- **JavaScript:** lowercase `.js` files at module root, e.g. `app/portfolio/frontend/server.js`
- **Python:** lowercase `.py` files, single module per concern, e.g. `app/portfolio/api/app.py`
- **Terraform:** split per concern in each module: `main.tf`, `variables.tf`, `outputs.tf`, `data-blocks.tf` (e.g. `terraform-infra/database/`)
- **YAML/Kubernetes:** lowercase with hyphens, often number-prefixed for ordering (`01-backend.yaml`, `02-frontend.yaml`); kustomize entrypoint `kustomization.yaml`
- **Helm templates:** `HelmCharts/portfolio/templates/` — kebab-case template files
- **Shell scripts:** kebab-case verb-noun (`scripts/cluster-creation.sh`, `scripts/bootstrap-flux.sh`, `scripts/destroy-cluster.sh`, `scripts/validation.sh`)
- **GitHub workflows:** kebab-case `.yaml` (`.github/workflows/portfolio-images.yaml`, `deploy-workflow.yaml`, `helmchart.yaml`, `validation-PT.yaml`)

### Functions
- **JavaScript:** camelCase; arrow callbacks `(req, res) => {...}`. Express handlers inline. Example: `app/portfolio/frontend/server.js`
- **Python:** snake_case; private helpers prefixed with underscore (`_is_rate_limited`, `_validate_payload`, `_send_email`, `_enforce_body_cap` in `app/portfolio/api/app.py`)
- **Terraform:** snake_case for resource names (`aws_db_instance.default`, `aws_s3_bucket.terraform_state`)

### Variables / Constants
- **JavaScript:** camelCase locals (`const app`), UPPER_SNAKE for env-derived constants (`const PORT`, `const BACKEND_URL`)
- **Python:** snake_case locals; UPPER_SNAKE for module-level config constants (`SMTP_HOST`, `RATE_LIMIT`, `EMAIL_RE`)
- **Terraform:** snake_case for variable inputs (`var.allocated_storage`, `var.engine_version`); legacy UPPER_SNAKE survives in some places (`var.ACCOUNT_ID`)

### Types / Models
- **Python:** PascalCase classes (Pydantic in legacy `app/backend/main.py`); current Flask app uses plain dicts validated by `_validate_payload`
- **Type hints:** Modern syntax (`dict[str, list[datetime]]`) in `app/portfolio/api/app.py`

### Kubernetes / Helm
- Labels: kebab-case (`app: portfolio-api`, `tier: backend`)
- Helm value paths: camelCase keys nested under semantic groups (`{{ .Values.namespace.name }}`)

## Code Style

### Formatting
- **JavaScript:** 2-space indent, double-quoted strings, semicolons present
- **Python:** 4-space indent (PEP 8), double-quoted strings preferred, blank lines between logical sections
- **Terraform:** 2-space indent, aligned `=` within blocks, comment-grouped attribute clusters (`# storage`, `# engine`, `# network`)
- **YAML:** 2-space indent throughout

### Linting / Formatting Tools
- **No `.eslintrc`, `.prettierrc`, `pyproject.toml`, `ruff.toml`, or `.editorconfig`** present at repo root
- **Terraform:** `terraform fmt -check` and `terraform validate` enforced in `.github/workflows/deploy-workflow.yaml`
- **Helm:** `helm lint` and `helm template` smoke render enforced in `.github/workflows/helmchart.yaml`
- **IaC security:** Checkov scans Terraform in `deploy-workflow.yaml` (`checkov --directory . --framework terraform --output cli --compact`)
- **Application code (JS/Python):** No lint, format, or type-check step in any workflow

### Section Separators
- **Python:** `# ---------------------------------------------------------------------------` block separators with section title underneath, e.g. `# Configuration`, `# Validation helpers`, `# Routes` in `app/portfolio/api/app.py`
- **JavaScript:** `// ── Section Name ───────────────` Unicode box-drawing separators in `app/portfolio/frontend/server.js`
- **Terraform:** `# storage`, `# engine`, `# network` short comments to group related attributes

## Import Organization

### Python (`app/portfolio/api/app.py`)
1. Stdlib (`os`, `re`, `smtplib`, `logging`, `email.*`, `datetime`, `collections`)
2. Blank line
3. Third-party (`flask`, `flask_cors`, `dotenv`)
- Specific imports preferred over wildcard

### JavaScript (`app/portfolio/frontend/server.js`)
- Optional `require("dotenv").config()` wrapped in `try/catch` (container-safe)
- `require()` calls grouped at top
- Destructuring used for sub-imports: `const { createProxyMiddleware } = require("http-proxy-middleware")`

### Path Aliases
- None configured (no `tsconfig.json`, no Babel/webpack alias)

## Error Handling

### JavaScript
- Proxy errors caught via `onError` callback returning HTTP 502 with structured JSON: `res.status(502).json({ success: false, error: "Backend service unavailable." })`
- Optional dependencies wrapped in `try { ... } catch (_) { /* comment */ }`
- Errors logged via `console.error` with bracketed prefix: `[Proxy Error] ${err.message}`

### Python (Flask)
- Error responses are uniform: `jsonify({"success": False, "error": "..."}), <status>` for single errors, `{"success": False, "errors": [...]}` for multi-field validation
- Status codes used: 400 (validation), 413 (oversize), 429 (rate limit), 500 (SMTP failure), 502 not used here
- `@app.errorhandler(413)` registered for body-cap overflow
- `@app.before_request` hook enforces ordering invariants (rate-limiter never sees oversized payloads — see SEC-07 ordering note in `app/portfolio/api/app.py:155`)
- Outer `try/except Exception as exc` wraps SMTP send; logs and returns generic 500 (no stack leak to client)

### Terraform / Kubernetes
- Failure surfaces via tooling exit codes (terraform plan/apply, helm lint, flux reconciliation)
- App-level fallback: HelmRelease auto-rollback on failed upgrade
- Liveness/readiness via `/health` endpoints on both services (frontend `/health` deliberately does NOT proxy upstream — independence requirement noted in `server.js:37`)

## Logging

### Python
- Stdlib `logging` configured at `INFO`: `logging.basicConfig(level=logging.INFO)`; module logger via `logging.getLogger(__name__)`
- Log messages use bracketed tag prefix: `logger.info(f"[CONTACT] Email sent — from {email}, subject: {subject}")`
- Levels used: `info` (success path), `warning` (degraded/dev mode), `error` (caught exceptions)
- f-strings throughout (acceptable here; not security-sensitive)

### JavaScript
- `console.log` and `console.error` only — no structured logger
- Startup banner uses `✦` emoji prefix:
  ```
  ✦  Frontend  → http://localhost:3000
  ✦  Backend   → http://localhost:5000
  ```
- Error prefix: `[Proxy Error]`

### Shell
- `echo` with banner separators (`echo "================="`)
- `>>>` prefix for status lines, trailing `✅` / `❌` for outcome (see `scripts/validation.sh`)

### Cluster
- Pods log to stdout; collected by EFK; Istio access logs via istiod values

## Function Design

- **Python helpers private by convention:** leading underscore (`_send_email`, `_validate_payload`)
- **Single-responsibility:** validation, rate-limit, SMTP build, and route handler kept in separate functions in `app/portfolio/api/app.py`
- **Type hints on helpers** (`def _is_rate_limited(ip: str) -> bool:`); Flask routes untyped (Flask convention)
- **JS handlers** are inline arrows; no extracted controller layer

## Module Design

- Each app is a single-file service (`server.js`, `app.py`) — monolithic but small
- Terraform splits by file role within a module; modules under `terraform-infra/` are reusable building blocks (`iam-role-module`, `networking/vpc-module`)
- Kubernetes manifests organized by base/overlay (`portfolio/base/`) and consumed via Flux Kustomization in `clusters/dev-projectx/`
- No barrel files / aggregated exports

## Configuration

### Application Configuration
- **All runtime config via env vars with safe defaults:**
  - JS: `process.env.PORT || 3000`, `process.env.BACKEND_URL || "http://localhost:5000"`
  - Python: `os.getenv("SMTP_HOST", "smtp.gmail.com")`, `int(os.getenv("RATE_LIMIT", 5))`
- `.env` loading is **optional** — wrapped in `try/catch` in JS, `load_dotenv()` no-ops if missing in Python
- Secrets sourced from Kubernetes Sealed Secrets (see commit `cbf24b9`); never committed in plaintext

### Terraform Configuration
- One file per concern within a module (`main.tf`, `variables.tf`, `outputs.tf`, `data-blocks.tf`)
- Variables documented with `description`; resources tagged with `Environment` and `Name`
- Backend config injected at `terraform init` via `-backend-config="bucket=${AWS_ACCOUNT_ID}-terraform-state-${ENV}"`
- Root workspaces under `terraform-infra/root/<env>/<stack>/` (dev/prod separation)

### Kubernetes Configuration
- Helm `values.yaml` for chart defaults; HelmRelease overrides per cluster
- Image tags pinned to git SHA via CI (`${{ github.sha }}` in `portfolio-images.yaml`); never `:latest`

## Commit Patterns

Conventional Commits in active use. Observed prefixes (last 25 commits):

| Prefix | Use |
|--------|-----|
| `feat(scope):` | new functionality (`feat(portfolio): wire SealedSecret SMTP creds`) |
| `fix(scope):` | bug fix (`fix(portfolio): align backend BACKEND_PORT with chart Service port 8000`) |
| `chore(scope):` | infra/CI/non-functional (`chore(portfolio): rename backend→api`) |
| `ci:` | workflow changes (`ci: extend terraform deploy matrix`) |
| `revert:` / `Revert "..."` | rollback |
| `docs:` | (used historically) |

- Scopes: `portfolio`, `chart`, `api`, none (root-level)
- Subject in imperative mood, lowercase after the colon, no trailing period
- Merge commits used for PR integration (`Merge pull request #98 from AltairYedressov/feature/...`)
- Branch names: `feature/<descriptor>` (e.g. `feature/PT**` triggers ephemeral test workflow; `feature/portfolio-v2-cutover`)
- "Retrigger" commits are common — indicates CI re-run via empty/no-op commit (consider workflow_dispatch instead)

## File Organization

### Repo Top Level
```
app/                  # Application source (portfolio/{api,frontend})
HelmCharts/           # Helm chart sources (portfolio/)
clusters/             # Flux Kustomizations per cluster (dev-projectx, test)
platform-tools/       # Cluster-wide tooling manifests (istio, karpenter, etc.)
portfolio/            # Application kustomize base/overlays
terraform-infra/      # IaC modules + root workspaces
scripts/              # Bash helpers for cluster lifecycle and validation
.github/workflows/    # CI/CD pipelines
docs/                 # Documentation
```

### Application Layout
- Each service self-contained: `app/portfolio/<service>/{Dockerfile, app.py|server.js, requirements.txt|package.json}`
- No `src/` subdirectory inside services — flat layout

### Terraform Layout
- Reusable modules at `terraform-infra/<concern>/` (e.g. `database/`, `networking/vpc-module/`)
- Root workspaces at `terraform-infra/root/<env>/<stack>/` (dev/eks, dev/networking, etc.)

### Kubernetes Layout
- Base manifests: `portfolio/base/`, `platform-tools/<tool>/<namespace>/base/`
- Cluster bindings: `clusters/dev-projectx/<app>.yaml` references the base via Flux Kustomization

## Where to Add New Code

| Need | Location |
|------|----------|
| New REST endpoint (Python API) | `app/portfolio/api/app.py` (single file) |
| New frontend route or proxy rule | `app/portfolio/frontend/server.js` |
| New AWS resource (reusable) | New module under `terraform-infra/<concern>/` |
| New AWS resource (consumer) | `terraform-infra/root/<env>/<stack>/main.tf` |
| New Helm template | `HelmCharts/portfolio/templates/<resource>.yaml` |
| New Flux-managed app | `clusters/dev-projectx/<app>.yaml` + base under `platform-tools/` or `portfolio/` |
| New CI job | `.github/workflows/<name>.yaml` (kebab-case) |
| New cluster lifecycle helper | `scripts/<verb>-<noun>.sh`, `chmod +x` |

---

*Convention analysis: 2026-04-15*
