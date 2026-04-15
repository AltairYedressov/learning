# Coding Conventions

**Analysis Date:** 2026-04-15

## Naming Patterns

**Files:**
- JavaScript/Node.js: kebab-case or camelCase
  - Examples: `server.js`, `package.json`, `main.js`
  - Express apps use simple lowercase names: `server.js`, `app.js`
- Python: lowercase_with_underscores
  - Examples: `main.py`, `app.py`, `requirements.txt`
  - Test files: `test_*.py` (e.g., `test_security.py`)
- Terraform: lowercase_with_underscores with logical file grouping
  - Examples: `main.tf`, `variables.tf`, `outputs.tf`, `data-blocks.tf`
- YAML/Kubernetes: kebab-case for resources and properties
  - Examples: `portfolio-api`, `portfolio-frontend`, `app: portfolio-api`, `tier: backend`

**Functions & Routes:**
- JavaScript (Express): camelCase for regular functions, lowercase REST verbs for routes
  - Route handlers: `app.get()`, `app.post()`, `app.listen()`
  - Arrow functions: `async (req, res)` or `(req, res, next)` middleware pattern
- Python (FastAPI/Flask): snake_case for all functions
  - Route handlers: `def get_profile()`, `def health()`, `def contact()`
  - Decorator pattern: `@app.get()`, `@app.post()`
- Python class names: PascalCase
  - Examples: `class Profile(BaseModel)`, `class HealthCheck(BaseModel)`, `class LimitRequestBodyMiddleware`

**Variables:**
- JavaScript: camelCase (const/let)
  - Examples: `const API_URL`, `const PORT`, `let started = false`
  - Constants: UPPER_CASE if exported globally
- Python: snake_case
  - Examples: `PROFILE`, `SKILLS`, `EXPERIENCE`, `_rate_store`, `client_ip`
  - Constants: UPPER_CASE
  - Private/internal: prefix with underscore (`_validate_payload()`, `_send_email()`)
- Terraform: UPPER_CASE for input variables, lowercase for resource references
  - Examples: `var.allocated_storage`, `aws_db_instance.default`

**Type & Data Model Names:**
- Pydantic models: PascalCase
  - Examples: `class Skill(BaseModel)`, `class Experience(BaseModel)`, `class HealthCheck(BaseModel)`
- Type hints: Python `typing` module
  - Examples: `List[str]`, `Optional[str]`, `List[Skill]`, `dict[str, list[datetime]]`
- Kubernetes labels: kebab-case with lowercase values
  - Examples: `app: portfolio-api`, `tier: backend`, `namespace: portfolio`

## Code Style

**Formatting:**
- JavaScript: 2-space indentation
  - Express app structure with clear sections marked by comments
  - Example: `// ── Main route ──────────────────────────────────────────────────────────────`
- Python: 4-space indentation (PEP 8)
  - Example: `app/backend/main.py` follows standard Python indentation
- Terraform: 2-space indentation in block structures
  - Example: `terraform-infra/database/main.tf` uses 2-space indents for nested blocks
- YAML/Kubernetes: 2-space indentation for all manifest files
  - Example: `HelmCharts/portfolio/templates/*.yaml` consistently use 2-space indents

**Linting:**
- Not detected - No `.eslintrc`, `.prettierrc`, `pyproject.toml`, or similar config files found
- Code follows common conventions but no enforced linting rules
- Visual separators used throughout codebase for code organization

**Comments:**
- ASCII art visual separators consistently used to organize code sections
  - JavaScript: `// ── Section Name ────────────────────────────────────────────`
  - Python: `# ── Section Name ────────────────────────────────────────────`
  - Terraform: `# ── Section Name ────────────────────────────────────────────`
  - YAML: `# ── Section Name ────────────────────────────────────────────`
- Module docstrings at top of files describe purpose
  - Python: Triple-quoted docstring at module level
    - Example: `"""Altair Yedressov — Portfolio API (Python / FastAPI)..."""`
  - JavaScript: Block comments at top
    - Example: `/** Altair Yedressov — Portfolio Frontend...*/`
- Minimal inline documentation; function names and type hints carry the meaning
- No over-commenting pattern — only clarifications where logic is not obvious

## Import Organization

**JavaScript/Node.js:**
1. Framework imports (`const express = require("express")`)
2. Third-party packages (`const axios = require("axios")`)
3. Standard library (`const path = require("path")`)
4. Local imports (relative paths if any)

Example from `app/frontend/src/server.js`:
```javascript
const express = require("express");
const axios = require("axios");
const path = require("path");
```

**Python:**
1. Standard library imports (`import os`, `import re`, `from datetime import...`)
2. Third-party packages (`from fastapi import FastAPI`, `from pydantic import BaseModel`)
3. Type imports separated (`from typing import List, Optional`)

Example from `app/backend/main.py`:
```python
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import datetime
```

**Path Aliases:**
- Not detected - No TypeScript or JavaScript path aliases configured
- All imports use relative/standard library paths

## Error Handling

**JavaScript/Express:**
- Try-catch blocks with async handlers
- Pattern: Catch block logs error with `console.error()` and returns HTTP status with fallback response
- Example from `app/frontend/src/server.js`:
  ```javascript
  try {
    const { data } = await axios.get(`${API_URL}/api/all`);
    res.render("index", { data });
  } catch (err) {
    console.error("Backend API unreachable:", err.message);
    res.status(503).render("error", {
      message: "Backend API is unreachable...",
    });
  }
  ```
- Silent catch (no error logging) used for non-critical failures
  - Example: `app/frontend/src/server.js` line 40: `catch { }` for degraded state
- HTTP status codes follow REST conventions: 503 for service unavailable
- Proxy error handlers use `console.error()` with descriptive context
  - Example from `app/portfolio/frontend/server.js`: `console.error(\`[Proxy Error] ${err.message}\`)`

**Python/FastAPI:**
- HTTPException raised for errors with appropriate status codes
  - Import: `from fastapi import HTTPException`
  - Example: Return 429 for rate limit, 413 for body too large, 404 for not found
- Pydantic validation built-in: Invalid data rejected by BaseModel validation
- Middleware-based approach for cross-cutting concerns (rate limiting, body size, CORS)
- Python Flask uses logging for errors:
  - `logger.warning()` for non-critical (e.g., SMTP not configured in dev)
  - `logger.error()` for actual failures
  - `logger.info()` for successful operations
  - Example from `app/portfolio/backend/app.py`:
    ```python
    except Exception as exc:
        logger.error(f"[CONTACT] Failed to send email: {exc}")
        return jsonify({...}), 500
    ```

**Logging Strategy:**
- JavaScript: `console.log()` for info, `console.error()` for errors
  - Pattern: Information-level logs with emoji prefix (`✦`)
    - Example: `console.log(\`✦  Frontend running → http://localhost:${PORT}\`)`
- Python: Standard `logging` module with `logger` instance
  - Structured: `logger.info()`, `logger.warning()`, `logger.error()`
  - Prefix pattern: `[CONTEXT]` in log message for categorization
- No structured logging framework (e.g., Winston, Pino) detected in JavaScript
- Environment-based verbosity: Flask checks `NODE_ENV` or `FLASK_DEBUG`

## Function Design

**JavaScript/Express:**
- Express middleware pattern with `(req, res)` or `(req, res, next)` signatures
- Route handlers are arrow functions or named async functions
- Response methods: `res.render()` for templating, `res.json()` for JSON, `res.status()` for HTTP status
- Example from `app/frontend/src/server.js`:
  ```javascript
  app.get("/", async (req, res) => {
    try {
      const { data } = await axios.get(`${API_URL}/api/all`);
      res.render("index", { data });
    } catch (err) {
      ...
    }
  });
  ```

**Python/FastAPI:**
- FastAPI handlers do not take request parameters directly in function signature
- Use `response_model` for automatic type validation and serialization
- Return native Python objects or Pydantic models (auto-serialized to JSON)
- Decorator-based routing: `@app.get()`, `@app.post()` at function level
- Example from `app/backend/main.py`:
  ```python
  @app.get("/api/profile", response_model=Profile)
  def get_profile(request: Request):
      return PROFILE
  ```
- Flask uses similar decorator pattern but with explicit `request` context:
  ```python
  @app.route("/api/contact", methods=["POST"])
  def contact():
      data = request.get_json(silent=True) or {}
  ```

**Python/Flask:**
- Request body extraction via `request.get_json(silent=True)`
- Return `jsonify()` for JSON responses, tuples for (data, status_code)
- Validation helpers are standalone functions (snake_case, prefixed with underscore if internal)
  - Example: `def _validate_payload(data: dict) -> list[str]`

## Module Design

**JavaScript:**
- Single app instance used throughout: `const app = express()`
- All routes attached to app: `app.get()`, `app.listen()`
- Middleware added via `app.use()` before routes that need it
- Single file structure for small services (`server.js` monolithic)

**Python:**
- Single FastAPI app instance: `app = FastAPI(...)`
- All routes attached to app: `@app.get()`, `@app.post()`
- Middleware added via `app.add_middleware()` in order (last added = outermost = runs first)
- Monolithic single-file structure with ASCII comment sections for logical separation
  - Example from `app/backend/main.py`:
    ```python
    # ── Data Models ──────────────────────────────────────────────────────────────
    # ── Static Data (from resume) ───────────────────────────────────────────────
    # ── Endpoints ────────────────────────────────────────────────────────────────
    ```

**Terraform:**
- Multiple files per concern (logical separation)
  - `main.tf`: Primary resource definitions
  - `variables.tf`: Input variable declarations with descriptions
  - `outputs.tf`: Output declarations
  - `data-blocks.tf`: Data source queries
- No barrel files or aggregated exports

**Kubernetes/YAML:**
- Multiple manifests per concern (logical separation via filenames)
  - Numbered prefixes for ordering: `01-backend.yaml`, `02-frontend.yaml`
  - Each manifest may contain multiple Kubernetes resources (Deployment, Service, etc.)
  - Visual section separators in comments: `# ── Backend Deployment ─────────`
- Consistent metadata structure: `name`, `namespace`, `labels`
- Template variable injection via Helm: `{{ .Values.namespace.name }}`

## Data Models

**Python/Pydantic:**
- All data models extend `BaseModel`
- Type hints required on all fields
- Optional fields marked with `Optional[FieldType]` or default values
- Example from `app/backend/main.py`:
  ```python
  class Profile(BaseModel):
      name: str
      title: str
      email: str
      phone: str
      location: str
      linkedin: str
      github: str
      summary: str
  ```
- Consistent use of `List[T]` for collections
  - Example: `items: List[str]`, `highlights: List[str]`
- `.dict()` method used to convert models to dictionaries for JSON serialization
  - Example: `PROFILE.dict()`, `[s.dict() for s in SKILLS]`

**JavaScript:**
- No TypeScript in use — plain JavaScript
- No type system; relies on runtime behavior
- Object destructuring common: `const { data } = await axios.get()`
- Dynamic object creation with properties: `{ status, service, version, timestamp }`

## Configuration Files

**Terraform:**
- Configuration split across logical files: `main.tf`, `variables.tf`, `outputs.tf`, `data-blocks.tf`
- Variables documented with `description` field in `variables.tf`
- Resources tagged with `Environment` and `Name` labels
- Consistent use of interpolation: `"${var.ACCOUNT_ID}-terraform-state-dev"`
- Data blocks in separate file for clarity
- Example structure from `terraform-infra/database/`:
  - `main.tf`: AWS RDS instance, subnet group, parameter group
  - `variables.tf`: All input variables with descriptions
  - `outputs.tf`: Outputs for downstream modules
  - `data-blocks.tf`: VPC, subnet, security group lookups

**YAML/Kubernetes:**
- YAML manifests follow standard Kubernetes API conventions
- Metadata includes `name`, `namespace`, `labels` with consistent app labels
- Labels follow pattern: `app: service-name`, `tier: frontend|backend`
- Resources templated with Helm: `{{ .Values.namespace.name }}`
- Comments use visual separators: `# ── Section Name ────────────────────`
- Multi-resource files separated by `---` delimiter
- Examples from `HelmCharts/portfolio/templates/01-backend.yaml`:
  - Deployment with security context, probes, resource limits
  - Service with selector matching deployment labels
  - Each section clearly marked with comment blocks

**Environment Configuration:**
- JavaScript: Read with `process.env.PORT`, `process.env.API_URL` with fallback defaults
  - Example: `const PORT = process.env.PORT || 3000`
- Python: `os.getenv()` for environment variables or `load_dotenv()` from .env files
  - Not extensively used in current code; hardcoded defaults in function signatures
- Framework configuration via environment-based conditional logic
  - Example from Flask: `if process.env.NODE_ENV === "production" ? "7d" : 0`

---

*Convention analysis: 2026-04-15*
