# syntax=docker/dockerfile:1.7
FROM node:20-alpine

ENV NODE_ENV=production \
    PORT=3000

RUN addgroup -g 10001 -S app \
 && adduser  -u 10001 -S app -G app -h /app -s /sbin/nologin

WORKDIR /app

COPY package.json package-lock.json* ./
RUN if [ -f package-lock.json ]; then \
      npm ci --omit=dev --no-audit --no-fund; \
    else \
      npm install --omit=dev --no-audit --no-fund; \
    fi

COPY server.js ./server.js
COPY public ./public

RUN chown -R app:app /app

USER app
EXPOSE 3000
CMD ["node", "server.js"]
