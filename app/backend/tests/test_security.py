"""
Security test suite for FastAPI backend.
Validates CORS restriction, rate limiting, body size enforcement, and 404 handling.
"""

import sys
import os

# Ensure the backend source directory is on the path so `from main import app` works
# when pytest is invoked from the tests/ directory or project root.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from fastapi.testclient import TestClient
from main import app


client = TestClient(app)


# ── CORS Tests ──────────────────────────────────────────────────────────────


def test_cors_rejects_unauthorized_origin():
    """GET /api/profile with Origin: https://evil.com must NOT echo that origin back."""
    response = client.get("/api/profile", headers={"Origin": "https://evil.com"})
    acao = response.headers.get("access-control-allow-origin")
    assert acao != "https://evil.com" and acao != "*", (
        f"Expected CORS to reject evil.com, but got access-control-allow-origin: {acao}"
    )


def test_cors_allows_authorized_origin():
    """GET /api/profile with Origin: https://yedressov.com must return matching ACAO header."""
    response = client.get("/api/profile", headers={"Origin": "https://yedressov.com"})
    acao = response.headers.get("access-control-allow-origin")
    assert acao == "https://yedressov.com", (
        f"Expected access-control-allow-origin: https://yedressov.com, got: {acao}"
    )


def test_cors_allows_localhost_origin():
    """GET /api/profile with Origin: http://localhost:3000 must return matching ACAO header."""
    response = client.get("/api/profile", headers={"Origin": "http://localhost:3000"})
    acao = response.headers.get("access-control-allow-origin")
    assert acao == "http://localhost:3000", (
        f"Expected access-control-allow-origin: http://localhost:3000, got: {acao}"
    )


# ── Rate Limiting Tests ────────────────────────────────────────────────────


def test_rate_limit_returns_429():
    """Sending 61 requests to /api/profile must result in a 429 on the 61st."""
    for i in range(61):
        response = client.get("/api/profile")
    assert response.status_code == 429, (
        f"Expected 429 after 61 requests, got {response.status_code}"
    )


def test_health_exempt_from_rate_limit():
    """Sending 70 requests to /api/health must all return 200 (exempt from rate limit)."""
    for i in range(70):
        response = client.get("/api/health")
        assert response.status_code == 200, (
            f"Request {i+1} to /api/health returned {response.status_code}, expected 200"
        )


# ── Body Size Tests ─────────────────────────────────────────────────────────


def test_oversized_body_rejected():
    """POST to /api/profile with body > 1024 bytes must return 413."""
    oversized_body = b"x" * 2048
    response = client.post(
        "/api/profile",
        content=oversized_body,
        headers={"content-length": "2048"},
    )
    assert response.status_code == 413, (
        f"Expected 413 for oversized body, got {response.status_code}"
    )


# ── 404 Handling Tests ──────────────────────────────────────────────────────


def test_unknown_path_returns_404():
    """GET /api/nonexistent must return 404 with JSON containing 'detail'."""
    response = client.get("/api/nonexistent")
    assert response.status_code == 404, (
        f"Expected 404 for unknown path, got {response.status_code}"
    )
    body = response.json()
    assert "detail" in body, f"Expected 'detail' in JSON body, got: {body}"
