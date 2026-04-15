# Testing Patterns

**Analysis Date:** 2026-04-15

## Summary

**There are no automated unit, integration, or end-to-end tests in this repository for application code.** Validation is performed entirely at the infrastructure and CI layer through static analysis (Checkov, terraform validate, helm lint) and a live-cluster smoke test (`scripts/validation.sh`) executed against an ephemeral EKS cluster.

This is a significant gap given the project is a security-audit / hardening initiative. See "Gaps" section.

## Test Framework

**None present for application code.**

- No `pytest`, `unittest`, `jest`, `vitest`, `mocha`, `playwright`, or `cypress` declared
- No `*test*.py`, `*.test.js`, `*.spec.js`, or `conftest.py` files exist anywhere in the repo (verified via Glob)
- No `tests/` or `__tests__/` directories
- Python `requirements.txt` (`app/portfolio/api/requirements.txt`) declares only runtime deps: `flask==3.1.1`, `flask-cors==5.0.1`, `python-dotenv==1.1.0`, `gunicorn==23.0.0`
- Node `package.json` (`app/portfolio/frontend/package.json`) declares only runtime deps; `scripts` block contains `start` and `dev` only — no `test` script

## What IS Validated

### 1. Static IaC Scanning (CI)

**Workflow:** `.github/workflows/deploy-workflow.yaml`
**Triggers:** push to `feature/**` and `main`; PR to `main` touching `terraform-infra/**`

| Step | Tool | Purpose |
|------|------|---------|
| Checkov IaC Scan | `checkov --directory . --framework terraform --output cli --compact` | Security/policy scan of Terraform |
| Terraform Format | `terraform fmt -check` | Style enforcement |
| Terraform Validate | `terraform validate` | Syntax + provider schema check |
| Terraform Plan | `terraform plan -input=false` | Dry-run against real AWS state |
| Terraform Apply | `terraform apply -auto-approve` | Only on `main` branch |

Currently the matrix is `stack: [eks]` — other stacks (networking, iam-roles, ecr, database, dns, s3) are **not** scanned per-PR despite existing in `terraform-infra/`. (Commit `bd021f5` extended matrix to iam-roles+ecr, but current file shows `[eks]` only.)

### 2. Helm Chart Validation (CI)

**Workflow:** `.github/workflows/helmchart.yaml`
**Triggers:** push/PR touching `HelmCharts/portfolio/**`

| Step | Command | Purpose |
|------|---------|---------|
| Helm lint | `helm lint HelmCharts/portfolio` | Schema + best-practice checks |
| Helm template | `helm template HelmCharts/portfolio > /tmp/rendered.yaml` | Smoke render to catch template errors |
| Helm package + push | `helm package` → `helm push oci://...ecr.../helm-charts` | Publish (main only) |

### 3. Container Image Build (CI)

**Workflow:** `.github/workflows/portfolio-images.yaml`
**Triggers:** push/PR touching `app/portfolio/**`

- Matrix builds `portfolio-web` and `portfolio-api` images via `docker/build-push-action@v6`
- PR builds: `push: false` — image is built but not pushed (build serves as compile-time validation)
- Main builds: tagged with git SHA, pushed to ECR
- **No image vulnerability scanning step** (no Trivy / Grype / `aws ecr start-image-scan`)

### 4. Live Cluster Smoke Test (CI)

**Workflow:** `.github/workflows/validation-PT.yaml` ("Ephemeral Cluster Test")
**Triggers:** push to `feature/PT**` branches only

Flow:
1. Provision temporary EKS cluster via `scripts/cluster-creation.sh`
2. Bootstrap Flux against the feature branch via `scripts/bootstrap-flux.sh`
3. Sleep 120s for reconciliation
4. Run `scripts/validation.sh`
5. Always destroy cluster via `scripts/destroy-cluster.sh`

**`scripts/validation.sh` checks:**
- All nodes `Ready` (timeout 120s)
- No pods in non-Running/non-Succeeded phase (excluding Completed/Terminating)
- Flux controllers rolled out and all Kustomizations reconciled (`flux get kustomizations` filtered for non-`True`)
- Grafana + Prometheus rollouts complete
- Karpenter (if installed) deployed, NodePool `Ready=True`
- EBS CSI controller rolled out

**Limitations of validation.sh:**
- It is a **liveness/health check**, not a behavioral test — it confirms pods exist and are healthy, not that they serve correct responses
- No HTTP probe against `/health`, `/api/health`, or `/api/contact`
- No assertion on Istio routing, certificate validity, or mTLS
- The fixed `sleep 120` is brittle — race conditions possible
- Trigger is narrow: only `feature/PT**` branches, not `main` and not portfolio-touching PRs

## Test File Organization

Not applicable — no test files exist.

If tests are added, recommended layout (consistent with existing flat-module convention):

| Service | Location | Framework |
|---------|----------|-----------|
| `app/portfolio/api/` | `app/portfolio/api/tests/test_*.py` | pytest |
| `app/portfolio/frontend/` | `app/portfolio/frontend/__tests__/*.test.js` | jest or vitest |
| Terraform modules | `terraform-infra/<module>/tests/` | Terratest (Go) or `terraform test` (HCL native, TF 1.6+) |
| Helm chart | `HelmCharts/portfolio/tests/` | `helm unittest` plugin or chart-testing (`ct`) |

## Coverage

**No coverage measurement configured.** No `.coveragerc`, `pyproject.toml [tool.coverage]`, `jest.config`, `nyc.config`, or coverage badges/gates anywhere.

Effective coverage of application logic: **0%** automated; manual verification only.

## CI Validation Summary

| Layer | Automated Check | Gate |
|-------|----------------|------|
| Terraform (eks stack only) | fmt, validate, Checkov, plan | PR + push |
| Terraform apply | apply | main only |
| Helm chart | lint, template render | PR + push |
| Helm publish | package, push to ECR OCI | main only |
| Container images | docker build (PR), build+push (main) | PR + push |
| Image vulnerabilities | **none** | — |
| Python app code | **none** (no lint, type-check, or test) | — |
| JS app code | **none** (no lint, no test) | — |
| Live cluster smoke | validation.sh on ephemeral EKS | `feature/PT**` branches only |
| Secret scanning | **none** (no gitleaks/trufflehog) | — |
| SAST | **none** for app code (Checkov is IaC-only) | — |
| Dependency scanning | **none** (no Dependabot config visible, no `pip-audit`, no `npm audit` step) | — |

## Gaps

High-impact gaps for a security-audit project:

1. **No application-level tests** — neither service has a single test. Validation logic in `app/portfolio/api/app.py` (`_validate_payload`, `_is_rate_limited`, body-cap enforcement, SMTP error handling) is security-sensitive and should be unit-tested. The `SEC-07` ordering invariant noted at `app.py:155` is enforced by code arrangement and has no regression test.
2. **No image vulnerability scanning** — ECR images pushed without Trivy/Grype scan or ECR enhanced scanning enforcement in CI
3. **No secret scanning** — repo history could leak credentials with no automated detection
4. **No SAST for application code** — Bandit (Python), Semgrep, or CodeQL not configured
5. **No dependency vulnerability scanning** — `pip-audit`, `npm audit --audit-level=high`, or Dependabot/Renovate alerts not visible in CI
6. **Terraform stack matrix incomplete** — only `eks` stack scanned; `networking`, `iam-roles`, `ecr`, `database`, `dns`, `s3` Terraform changes bypass per-PR Checkov+plan
7. **Smoke test trigger too narrow** — `validation-PT.yaml` only fires on `feature/PT**`; PRs from other branches (including portfolio cutovers) merge without ever booting an ephemeral cluster
8. **Smoke test is health-only** — does not exercise contact-form happy path, rate-limit (429), oversize (413), or invalid payload (400)
9. **No Istio policy / mTLS verification** — strict mTLS, AuthorizationPolicy presence not asserted
10. **No Helm `kubeconform` / `kubeval`** — rendered manifests not validated against Kubernetes API schema
11. **No `terraform test` blocks** — Terraform 1.6+ native testing unused despite `terraform_version: 1.6.6` pin in CI
12. **Flaky retrigger pattern** — multiple "retrigger" commits in history indicate CI flakiness not being root-caused

## Recommended Next Steps (in priority order)

1. Add `pytest` + tests for `_validate_payload`, `_is_rate_limited`, `_enforce_body_cap` ordering, and SMTP error path (mock `smtplib.SMTP`)
2. Add `npm test` with vitest covering proxy `pathFilter`, `/health` independence, and CSP header presence
3. Add Trivy or `aws ecr-scan` step to `portfolio-images.yaml`
4. Add `gitleaks` workflow (push + PR) — critical for security audit deliverable
5. Add Bandit (Python) + Semgrep (multi-lang) SAST workflow
6. Restore full Terraform stack matrix in `deploy-workflow.yaml`
7. Add `kubeconform` step in `helmchart.yaml` after `helm template`
8. Replace `sleep 120` in `validation-PT.yaml` with `kubectl wait` + add HTTP probes against the Istio Gateway

---

*Testing analysis: 2026-04-15*
