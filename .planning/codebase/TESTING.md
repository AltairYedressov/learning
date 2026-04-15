# Testing

## Framework

- **pytest** — Python backend test framework
- **fastapi.testclient.TestClient** — In-process HTTP client (no real server needed)
- No JavaScript/frontend test suite present
- No Terraform/infrastructure test framework (no terratest, kitchen-terraform)
- No Helm chart test framework (no helm-unittest)

## Test Location

- `app/backend/tests/` — Python backend tests
  - `app/backend/tests/__init__.py` — Package marker
  - `app/backend/tests/test_security.py` — Security-focused integration tests

## Run Commands

```bash
# From app/backend/ or project root:
pytest app/backend/tests/
# Or directly:
cd app/backend && pytest tests/
```

No pytest config (`pytest.ini`, `pyproject.toml`, `setup.cfg`) present — relies on defaults.

## Structure

- **Single file**, categorized via ASCII section headers matching backend style:
  - `# ── CORS Tests ──────────────────────────────────────────────────────────────`
  - `# ── Rate Limiting Tests ────────────────────────────────────────────────────`
  - `# ── Body Size Tests ─────────────────────────────────────────────────────────`
  - `# ── 404 Handling Tests ──────────────────────────────────────────────────────`
- Test function names: `test_<behavior>_<expected_outcome>` (e.g., `test_cors_rejects_unauthorized_origin`, `test_oversized_body_rejected`)
- Docstrings describe the behavior in plain English on the first line

## Pattern Example

```python
def test_cors_rejects_unauthorized_origin():
    """GET /api/profile with Origin: https://evil.com must NOT echo that origin back."""
    response = client.get("/api/profile", headers={"Origin": "https://evil.com"})
    acao = response.headers.get("access-control-allow-origin")
    assert acao != "https://evil.com" and acao != "*", (
        f"Expected CORS to reject evil.com, but got access-control-allow-origin: {acao}"
    )
```

## Path Bootstrapping

Tests insert the parent directory into `sys.path` so `from main import app` works regardless of the invocation CWD:

```python
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from main import app
```

## Mocking Approach

- **No mocking libraries in use** — no `unittest.mock`, no `pytest-mock`, no `responses`
- Tests exercise the real FastAPI app in-process via `TestClient`
- No external dependencies to mock (backend is stateless, data is hardcoded)

## Fixtures

- No `conftest.py` present
- No `@pytest.fixture` definitions
- Shared state: single module-level `client = TestClient(app)` reused by all tests

## Coverage

- **Not measured** — no coverage tool configured (no `.coveragerc`, no `pytest-cov` in deps)
- No CI coverage gate
- Scope is intentional: these are **security regression tests** for phase-05 hardening, not broad unit coverage

## Test Inventory (7 tests)

| Test | Purpose |
|------|---------|
| `test_cors_rejects_unauthorized_origin` | CORS rejects `https://evil.com` |
| `test_cors_allows_authorized_origin` | CORS allows `https://yedressov.com` |
| `test_cors_allows_localhost_origin` | CORS allows `http://localhost:3000` (dev) |
| `test_rate_limit_returns_429` | 61st request to `/api/profile` returns 429 |
| `test_health_exempt_from_rate_limit` | 70 requests to `/api/health` all 200 |
| `test_oversized_body_rejected` | POST > 1024 bytes returns 413 |
| `test_unknown_path_returns_404` | Unknown path returns 404 with `detail` JSON |

## Test Types Present

- **Integration tests** (in-process HTTP via TestClient) — all 7 tests
- **Unit tests** — none
- **E2E tests** (real cluster, real NLB) — none automated; manual smoke via curl
- **Infrastructure tests** — none (Terraform plan/apply serves as validation)

## CI Integration

- `.github/workflows/` exists but tests are **not wired into CI** — no pytest invocation in deploy pipeline
- Tests must be run manually before commits

## Gaps

- No frontend tests (Express server untested)
- No contract tests between frontend ↔ backend
- No chart-rendering tests (Helm templates unvalidated)
- No Terraform plan-diff tests
- No coverage enforcement
- No CI gate — tests can regress silently
