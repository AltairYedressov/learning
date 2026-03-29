# -- Backend: Python FastAPI --------------------------------------------------
FROM python:3.12-slim AS backend

WORKDIR /app

# Create non-root user (UID/GID 1001 per D-02)
RUN groupadd -g 1001 appgroup && useradd -u 1001 -g appgroup -d /app appuser

COPY --chown=appuser:appgroup requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=appuser:appgroup main.py .

# Prevent Python from writing .pyc files (readOnlyRootFilesystem compat)
ENV PYTHONDONTWRITEBYTECODE=1

USER appuser

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
