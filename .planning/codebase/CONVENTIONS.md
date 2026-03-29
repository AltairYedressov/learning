# Coding Conventions

**Analysis Date:** 2026-03-28

## Naming Patterns

**Files:**
- JavaScript/Node.js: camelCase or kebab-case (`server.js`, `package.json`)
- Python: lowercase_with_underscores (`main.py`, `requirements.txt`)
- Terraform: lowercase_with_underscores (`main.tf`, `variables.tf`, `outputs.tf`)
- YAML/Kubernetes: lowercase with hyphens (`portfolio.yaml`, `kustomization.yaml`)
- Shell scripts: lowercase with hyphens (`cluster-creation.sh`, `bootstrap-flux.sh`)

**Functions (JavaScript):**
- camelCase for regular functions: `async (req, res)` arrow functions
- Route handlers use lowercase REST verb pattern: `app.get()`, `app.post()`
- Example: `axios.get()`, `express.static()`

**Functions (Python):**
- snake_case: `get_profile()`, `get_skills()`, `get_experience()`
- Class names: PascalCase (`BaseModel`, `FastAPI`, `HTTPException`)
- Example from `app/backend/main.py`: All endpoint handlers use snake_case

**Variables:**
- JavaScript: camelCase (`const app = express()`, `const PORT = 3000`, `const API_URL`)
- Python: snake_case and UPPER_CASE for constants (`PROFILE`, `SKILLS`, `EXPERIENCE`, `CERTIFICATIONS`, `PROJECTS`)
- Terraform: UPPER_CASE for variables (`ACCOUNT_ID`), lowercase for resource references (`aws_s3_bucket.terraform_state`)

**Types (Python):**
- Pydantic models use PascalCase: `class Profile(BaseModel)`, `class Skill(BaseModel)`, `class Experience(BaseModel)`
- Type hints with Python typing module: `List[str]`, `List[Skill]`, `Optional[str]`
- Example from `app/backend/main.py`: `class HealthCheck(BaseModel)`

**Resource Labels (Kubernetes/Terraform):**
- kebab-case for labels and names: `app: portfolio-api`, `tier: backend`
- snake_case for variable names: `aws_internet_gateway.igw`, `aws_s3_bucket.terraform_state`

## Code Style

**Formatting:**
- JavaScript: 2-space indentation (Express app uses standard Node.js patterns)
- Python: 4-space indentation (PEP 8 standard observed in `app/backend/main.py`)
- Terraform: 2-space indentation in block structures
- YAML/Kubernetes: 2-space indentation for all manifest files

**Linting:**
- Not detected - No `.eslintrc`, `.pylintrc`, or linter configuration files found
- Code follows common conventions but no enforced linting rules

**Code Comments:**
- Visual separators with ASCII art: `# ── Data Models ──────────────────────────────────────────────────────────────`
- Used consistently in `app/backend/main.py` to section logical code blocks
- Used in `app/frontend/src/server.js` with `// ── Main route ──────────────────────────────────────────────────────────────`
- Short inline comments for clarification, avoiding over-commenting

## Documentation

**Module-level Docstrings:**
- Python: Module docstrings at the top describe purpose
  - Example: `"""Altair Yedressov — Portfolio API (Python / FastAPI) Serves resume data as JSON endpoints for the Node.js frontend."""`
- JavaScript: Block comments at top describe module purpose
  - Example: `/** * Altair Yedressov — Portfolio Frontend (Node.js / Express) * Fetches data from the Python FastAPI backend and renders a single-page portfolio. */`

**Function Documentation:**
- Python: Minimal - simple endpoint handlers rely on function names and type hints
- Python type hints used throughout: `response_model=Profile`, `response_model=List[Skill]`
- JavaScript: JSDoc-style comments absent; function clarity through naming and middleware

## Import Organization

**JavaScript (Node.js):**
1. Built-in modules: `const express = require("express")`
2. Third-party packages: `const axios = require("axios")`
3. Standard library: `const path = require("path")`
4. Order observed in `app/frontend/src/server.js`

**Python:**
1. Standard library: `from fastapi import`, `import datetime`
2. Third-party imports: `from pydantic import BaseModel`, `from typing import List`
3. Local imports: None present in analyzed code
- Type imports separated: `from typing import List, Optional`

**Path Aliases:**
- Not detected - No TypeScript path aliases configured
- All imports use relative/standard library paths

## Error Handling

**JavaScript (Express):**
- Try-catch blocks with async handlers
- Pattern: Catch block logs error with `console.error()` and returns HTTP status with fallback response
- Example from `app/frontend/src/server.js` line 19-28:
  ```javascript
  try {
    const { data } = await axios.get(`${API_URL}/api/all`);
    res.render("index", { data });
  } catch (err) {
    console.error("Backend API unreachable:", err.message);
    res.status(503).render("error", {
      message: "Backend API is unreachable. Ensure the Python service is running.",
    });
  }
  ```
- Silent catch (no error message) for non-critical failures: Line 40 `catch { }` for degraded state
- HTTP status codes: 503 for service unavailable

**Python (FastAPI):**
- HTTPException raised for errors: `from fastapi import HTTPException`
- Not extensively used in current code (simple endpoints return data directly)
- Pydantic validation built-in: Invalid data rejected by BaseModel validation

## Environment Configuration

**Environment Variables:**
- JavaScript: Read with `process.env.PORT`, `process.env.API_URL` with fallback defaults
  - Pattern: `const PORT = process.env.PORT || 3000;`
  - Pattern: `const API_URL = process.env.API_URL || "http://localhost:8000";`
- Python: Not actively used in current code; could use `os.getenv()`

**Logging:**
- Framework: `console.log()` and `console.error()` (JavaScript), `print()` (Python, not extensively used)
- Pattern in JavaScript: Information-level logs with emoji prefix (`✦`)
  - Example: `console.log("✦  Frontend running → http://localhost:${PORT}")`
- Error logs: `console.error("Backend API unreachable:", err.message)`
- No structured logging framework detected

## Function Design

**Size:** Endpoint handlers are small (5-15 lines) focused on single responsibility

**Parameters:**
- JavaScript: Express middleware pattern with `(req, res)` or `(req, res, next)`
- Python: FastAPI handlers take no request parameters directly; use `response_model` for type validation

**Return Values:**
- JavaScript: `res.render()` for template rendering, `res.json()` for JSON, `res.status()` for HTTP responses
- Python: Return native Python objects, Pydantic models serialized automatically to JSON

## Module Design

**Exports:**
- JavaScript: Single app instance used throughout: `app.get()`, `app.listen()`
- Python: Single FastAPI app instance: `@app.get()`, `@app.post()`
- No barrel files or aggregated exports in analyzed code

**Code Organization:**
- JavaScript: Single file (`server.js`) - monolithic but simple for small service
- Python: Single file (`main.py`) - monolithic structure with clear section separation via ASCII comments
- Terraform: Multiple files per concern (main.tf, variables.tf, outputs.tf, data-blocks.tf) - modular pattern
- Kubernetes: Multiple manifests per concern (01-backend.yaml, 02-frontend.yaml) - clear ordering via numbers

## Data Models

**Python (Pydantic):**
- All data models extend `BaseModel`
- Type hints required on all fields
- Optional fields marked with `Optional[FieldType]` or default values
- Example: `class Profile(BaseModel):` with typed fields
- Consistent use of `List[T]` for collections
- `.dict()` method used to convert models to dictionaries for JSON serialization

**JavaScript:**
- No type system (plain JavaScript); relies on runtime behavior
- Object destructuring used: `const { data } = await axios.get()`

## Configuration Files

**terraform-infra:**
- Terraform configuration split across logical files: `main.tf`, `variables.tf`, `outputs.tf`, `data-blocks.tf`
- Variables documented with `description` field
- Resources tagged with `Environment` and `Name` labels
- Consistent use of interpolation: `"${var.ACCOUNT_ID}-terraform-state-dev"`

**Kubernetes/Helm:**
- YAML manifests follow standard Kubernetes API conventions
- Metadata includes `name`, `namespace`, `labels` with consistent app labels
- Resources templated with Helm: `{{ .Values.namespace.name }}`
- Comments use visual separators: `# ── Section Name ────────────────────`

---

*Convention analysis: 2026-03-28*
