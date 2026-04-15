# syntax=docker/dockerfile:1.7

# ── Builder stage: install deps into a venv ────────────────────────────────
FROM python:3.12-slim-bookworm AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

RUN apt-get update \
 && apt-get install -y --no-install-recommends build-essential \
 && rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── Final stage: minimal runtime ───────────────────────────────────────────
FROM python:3.12-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    BACKEND_PORT=8000

# Non-root principal (CONTEXT D-05: uid/gid 10001)
RUN groupadd --system --gid 10001 app \
 && useradd  --system --uid 10001 --gid app --home /app --shell /usr/sbin/nologin app

WORKDIR /app

# Copy virtualenv from builder
COPY --from=builder /opt/venv /opt/venv

# Copy application source (owned by app user)
COPY --chown=app:app app.py ./

USER app

EXPOSE 8000

# gunicorn single-worker (CONTEXT D-04). Using shell form so ${BACKEND_PORT}
# expands at container start time.
CMD ["sh", "-c", "exec gunicorn -w 1 -b 0.0.0.0:${BACKEND_PORT:-8000} app:app"]
