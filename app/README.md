# Applications

This directory contains the portfolio application source.

## Layout

- `portfolio/backend/` — Flask API (image: `portfolio-api`). Hardened non-root container; see Phase 1 summary in `.planning/phases/01-package-local-verify/01-SUMMARY.md` for build + verify details.
- `portfolio/frontend/` — Express web server (image: `portfolio-web`). Proxies `/api/*` to the backend; serves EJS templates for the portfolio content.
- `portfolio/README.md` — local build and verification recipe.

## CI

Both images are built and pushed to ECR on every push to `main` that touches `app/portfolio/**` via `.github/workflows/portfolio-images.yaml`. The Helm chart under `HelmCharts/portfolio/` consumes the resulting `portfolio-api` and `portfolio-web` tags.

## Retired

The former `app/backend/` (FastAPI) and `app/frontend/` (EJS-only) trees were removed in Phase 3. They remain recoverable from git history if needed. Their former ECR repos under `images/portfolio-backend` and `images/portfolio-frontend` are orphaned and may be deleted manually once Phase 4 confirms prod stability.
