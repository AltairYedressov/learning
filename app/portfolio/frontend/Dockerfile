# syntax=docker/dockerfile:1.7

# ── Builder stage: install production deps ─────────────────────────────────
FROM node:20-alpine AS builder

ENV NODE_ENV=production
WORKDIR /build

# If a lockfile exists prefer `npm ci` for determinism; fall back to `npm install`.
COPY package.json ./
COPY package-lock.json* ./
RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev --no-audit --no-fund; \
    else \
      npm install --omit=dev --no-audit --no-fund; \
    fi

# ── Final stage: minimal runtime ───────────────────────────────────────────
FROM node:20-alpine AS runtime

ENV NODE_ENV=production \
    PORT=3000

# Non-root principal (CONTEXT D-05: uid/gid 10001)
RUN addgroup -g 10001 -S app \
 && adduser  -u 10001 -S app -G app -h /app -s /sbin/nologin

WORKDIR /app

# Copy installed modules from builder
COPY --from=builder --chown=app:app /build/node_modules ./node_modules
COPY --from=builder --chown=app:app /build/package.json ./package.json

# Copy application source (server.js + public/)
COPY --chown=app:app server.js ./server.js
COPY --chown=app:app public ./public

USER app

EXPOSE 3000

CMD ["node", "server.js"]
