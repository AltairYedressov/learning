# Testing Patterns

**Analysis Date:** 2026-03-28

## Test Framework

**Current State:**
- No test files detected in the application code
- No test runner configuration found (no `jest.config.js`, `vitest.config.js`, `pytest.ini`)
- No testing dependencies in `package.json` or `requirements.txt`

**Frameworks Available:**
- JavaScript/Node.js: Could use Jest, Vitest, or Mocha
- Python: Could use pytest, unittest, or hypothesis

**Recommendation:**
- For `app/frontend/src/server.js`: Jest with supertest for Express integration testing
- For `app/backend/main.py`: pytest with fastapi.testclient for API testing

## Application Architecture Overview

Understanding the codebase structure for future testing implementation:

**Frontend (`app/frontend/src/server.js`):**
- Express.js application with two main routes
- `/` - Main route that fetches data from backend API and renders template
- `/health` - Health check endpoint
- Error handling via try-catch blocks
- Dependencies: express, axios, ejs

**Backend (`app/backend/main.py`):**
- FastAPI application with 6 RESTful endpoints
- `/api/health` - Health check with HealthCheck model
- `/api/profile` - Returns Profile model
- `/api/skills` - Returns List[Skill]
- `/api/experience` - Returns List[Experience]
- `/api/certifications` - Returns List[Certification]
- `/api/projects` - Returns List[Project]
- `/api/all` - Aggregated endpoint returning all data as dictionary
- CORS middleware enabled for all origins
- Dependencies: fastapi, uvicorn, pydantic

## Test Strategy (Not Yet Implemented)

### Unit Tests

**Frontend (JavaScript):**
- Test route handlers independently with mocked axios
- Mock patterns: Jest mock for axios HTTP requests
- Mock API responses to test both success and failure paths
- Assertions on response status codes and rendered templates

Example test structure (not yet in codebase):
```javascript
describe('GET /', () => {
  it('should render index with data from backend', async () => {
    // Mock axios to return sample data
    // Assert res.render called with correct data
  });

  it('should handle backend API failure', async () => {
    // Mock axios to throw error
    // Assert 503 status and error template rendered
  });
});
```

**Backend (Python):**
- Test endpoint handlers return correct Pydantic models
- Test model validation with pytest
- Test CORS middleware configuration
- Assertions on response schemas and status codes

Example test structure (not yet in codebase):
```python
def test_get_profile():
    response = client.get("/api/profile")
    assert response.status_code == 200
    assert response.json()["name"] == "Altair Yedressov"

def test_health_check():
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
```

### Integration Tests

**Frontend:**
- Test full request flow from route handler to template rendering
- Use supertest to make real HTTP requests to Express app
- Test error scenarios (backend unreachable)

**Backend:**
- Test endpoint interactions (e.g., verify `/api/all` aggregates data correctly)
- Use FastAPI's TestClient to make test requests

### Error Path Testing

**Frontend:**
- Test axios failure scenarios (timeout, 500 error, connection refused)
- Verify 503 status code returned
- Verify error template rendered with appropriate message

**Backend:**
- Pydantic validation failures already handled by framework
- Test invalid request paths return 404

## Mocking Strategy (For Future Implementation)

**Frontend Mocking:**
- Jest mocks for axios: `jest.mock('axios')`
- Mock return values: `axios.get.mockResolvedValue({ data: {...} })`
- Mock errors: `axios.get.mockRejectedValue(new Error('...'))`
- Template rendering: Mock or test actual ejs rendering

**Backend Mocking:**
- FastAPI TestClient - no external mocking needed for unit tests
- Mock datetime for consistent timestamp testing if needed
- CORS middleware testing: Verify headers on OPTIONS requests

## Coverage Targets (Recommended)

**Frontend:**
- Route handlers: 100% - Small functions, critical for service
- Error paths: 100% - Must verify 503 responses work
- Axios integration: 80%+ - Mock external API calls

**Backend:**
- Endpoint handlers: 100% - Simple pass-through functions
- Model validation: 100% - Pydantic handles this
- Health check: 100% - Critical for Kubernetes probes

**Current State:**
- No coverage reported - testing not yet implemented

## Test Organization (Recommended Structure)

**Frontend:**
- Location: `app/frontend/test/` or `app/frontend/__tests__/`
- Naming: `*.test.js` or `*.spec.js`
- Structure: One file per route or feature

**Backend:**
- Location: `app/backend/test/` or `app/backend/tests/`
- Naming: `test_*.py` or `*_test.py`
- Structure: One file per module or feature

## Run Commands (To Be Implemented)

**Frontend (once configured):**
```bash
npm test                   # Run all tests
npm test -- --watch       # Watch mode
npm test -- --coverage    # Coverage report
```

**Backend (once configured):**
```bash
pytest                     # Run all tests
pytest -v                  # Verbose output
pytest --cov=app          # Coverage report
pytest -k health          # Run specific test
```

## Health Check Testing

**Frontend (`app/frontend/src/server.js` line 32-47):**
- GET `/health` endpoint exists and returns JSON
- Returns degraded status if backend unreachable
- Structure:
  ```javascript
  {
    status: "healthy" | "degraded",
    service: "portfolio-frontend",
    backend: { /* backend response */ } | "unreachable"
  }
  ```
- Used by Kubernetes liveness/readiness probes

**Backend (`app/backend/main.py` line 153-160):**
- GET `/api/health` endpoint returns HealthCheck model
- Response includes: status, service, version, timestamp
- Used by Kubernetes liveness/readiness probes in Helm chart (`HelmCharts/portfolio/templates/01-backend.yaml` line 33-44)

## Kubernetes Integration (Relevant for Testing)

**Helm Chart Health Probe Configuration:**
- Location: `HelmCharts/portfolio/templates/01-backend.yaml`
- Liveness probe: checks `/api/health` every 15 seconds after 10s delay
- Readiness probe: checks `/api/health` every 10 seconds after 5s delay
- Tests must ensure health endpoints respond within probe timeouts

**Frontend Probe Configuration:**
- Location: `HelmCharts/portfolio/templates/02-frontend.yaml`
- Similar probes configured for `/health` endpoint

## Testing Best Practices for This Codebase

**For Frontend:**
1. Always mock axios calls - never make real HTTP requests in tests
2. Test both success and error paths for API integration
3. Verify correct HTTP status codes returned to client
4. Test template rendering with sample data

**For Backend:**
1. Use FastAPI TestClient for all endpoint tests
2. Test Pydantic model validation
3. Verify CORS headers on responses
4. Test health check timestamp is set

**For Both:**
1. Test health check endpoints thoroughly - critical for production
2. Verify error messages are appropriate
3. Test environment variable fallbacks (PORT, API_URL)
4. Integration tests should verify service-to-service communication

## Current Code Readiness for Testing

**Frontend (`app/frontend/src/server.js`):**
- Easily testable: Route handlers are pure functions with clear inputs/outputs
- Uses middleware pattern compatible with supertest
- Error handling patterns are testable
- Dependencies (axios, express, ejs) all have mature testing libraries

**Backend (`app/backend/main.py`):**
- Highly testable: Endpoints use Pydantic response models
- FastAPI has excellent built-in testing support
- CORS middleware easy to verify
- Data is hardcoded (no database) - tests can run without external dependencies
- Type hints enable property-based testing with hypothesis

---

*Testing analysis: 2026-03-28*
