# -- Frontend: Node.js + Express ----------------------------------------------
FROM node:20-alpine

WORKDIR /app

# Create non-root user (UID/GID 1001 per D-02)
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -D appuser

COPY --chown=appuser:appgroup package.json package-lock.json* ./
RUN npm install --production

COPY --chown=appuser:appgroup . .

USER appuser

EXPOSE 3000

CMD ["node", "src/server.js"]
