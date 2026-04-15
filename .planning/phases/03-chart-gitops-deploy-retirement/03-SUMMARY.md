---
phase: 3
name: Chart, GitOps Deploy & Old-App Retirement
status: human_needed
completed_plans: [03-01, 03-02, 03-03, 03-04, 03-05, 03-06]
requirements_completed: [DEP-01, DEP-02, DEP-03, DEP-04, DEP-05, SEC-01, SEC-03, SEC-04, SEC-06, CI-04]
tech_stack:
  added:
    - "Istio AuthorizationPolicy (security.istio.io/v1) for mesh-level mTLS principal enforcement"
  patterns:
    - "Chart values.yaml + HelmRelease inline values as dual source; HelmRelease wins at apply time"
    - "Image-automation annotation markers on image lines (Flux rewrites tag in place)"
    - "Lint-first CI (helm lint + helm template before AWS steps)"
key_files:
  created:
    - HelmCharts/portfolio/values.yaml
    - HelmCharts/portfolio/templates/00-serviceaccounts.yaml
    - portfolio/base/authorizationpolicy.yaml
  modified:
    - HelmCharts/portfolio/Chart.yaml
    - HelmCharts/portfolio/templates/01-backend.yaml
    - HelmCharts/portfolio/templates/02-frontend.yaml
    - portfolio/base/helmrelease.yaml
    - portfolio/base/virtualservice.yaml
    - portfolio/base/networkpolicy.yaml
    - portfolio/base/kustomization.yaml
    - .github/workflows/helmchart.yaml
    - app/README.md
  deleted:
    - app/backend/**
    - app/frontend/**
    - .github/workflows/image.yaml
decisions:
  - "Chart value keys renamed frontend->web; api stays (D-02)"
  - "Backend port 5000 everywhere (D-01)"
  - "Sealed SMTP creds mounted via envFrom: secretRef: portfolio-smtp on api only (D-04)"
  - "Dedicated ServiceAccounts portfolio-api / portfolio-web for distinct SPIFFE principals (D-10)"
  - "Istio AuthorizationPolicy ALLOW-only for portfolio-web SA + istio-ingressgateway SA (D-08)"
  - "SMTP egress port 587 added to portfolio-api NetworkPolicy (enables Phase 4 contact form)"
  - "Chart version bumped to 0.2.0 (minor — breaking rename); appVersion mirrors"
  - "HelmRelease pin policy: option-a TRACK LATEST (no version pin) — auto-selected per auto-mode protocol"
  - "Legacy .github/workflows/image.yaml deleted as part of retirement (pointed at deleted paths)"
---

# Phase 3: Chart, GitOps Deploy & Old-App Retirement — Summary

Phase 3 delivers a coherent Helm chart + GitOps base that deploys the Phase-1/Phase-2 `portfolio-web` + `portfolio-api` images with sealed SMTP credentials, mesh-level mTLS AuthZ, and a hardened chart-publish CI path — then retires the old FastAPI/EJS source trees.

## Plans Executed

| Plan | Commit | One-liner |
|------|--------|-----------|
| 03-01 | `b37fd3c` | Chart values.yaml + ServiceAccounts + port-5000 backend with envFrom portfolio-smtp + explicit non-secret env vars |
| 03-02 | `f4a3aeb` | Frontend template renamed portfolio-frontend -> portfolio-web, rekeyed .Values.web, SA + NODE_ENV=production |
| 03-03 | `fda2a2c` | portfolio/base rewire: HelmRelease values, VirtualService 5000/3000, NetworkPolicy rename + SMTP egress 587, new AuthorizationPolicy (D-08), kustomization register |
| 03-04 | `b1491ca` | Helm chart publish workflow hardened: lint-first, narrowed path filter, concurrency group, OIDC, job summary |
| 03-05 | `015061e` | Retire app/backend + app/frontend trees; delete legacy image.yaml workflow; rewrite app/README.md |
| 03-06 | `26f8197` | Chart.yaml version 0.1.0 -> 0.2.0; appVersion 0.2.0; HelmRelease left unpinned (track-latest) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed legacy .github/workflows/image.yaml**
- **Found during:** Plan 03-05 Task 1 (pre-check grep).
- **Issue:** `image.yaml` still built from `app/backend` / `app/frontend` — deleting those trees (Task 2) would silently break main-branch CI. The workflow is superseded by `portfolio-images.yaml` which already builds from `app/portfolio/**`.
- **Fix:** `git rm .github/workflows/image.yaml` in the same commit as the tree removal.
- **Commit:** `015061e`

**2. [Auto-decision] Plan 03-06 Task 2 checkpoint auto-resolved**
- Auto-mode checkpoint policy requires first option; selected **option-a: track latest (no pin)**.
- Effect: Plan 03-06 Task 3 becomes a no-op (HelmRelease already omits `spec.chart.spec.version`). No file change.
- Rationale recorded in commit `26f8197`.

### Out-of-scope observations (not fixed)
- `CLAUDE.md` still references `app/backend/main.py` and `app/frontend/src/server.js` in the auto-generated "tech stack" section. Not a build/deploy path; documentation only. Regenerate with your CLAUDE-profile tooling post-merge.
- `.github/workflows/deploy-workflow.yaml` had a pre-existing uncommitted modification — left untouched.

## Human Checkpoints Pending

Three real-world checkpoints remain (all Phase 3 plans are code-complete, but the cluster has not been touched):

### Checkpoint H-1: Merge + chart publish workflow run (Plan 03-04 Task 2)
After merge to main:
- GitHub Actions run **Portfolio Chart - Lint & Publish** triggered by the merge should succeed.
- `aws ecr describe-images --repository-name helm-charts/portfolio --region us-east-1` lists tag `0.2.0`.

### Checkpoint H-2: Sealed secret replacement (Phase 2 hand-off)
User must replace placeholder ciphertext in `HelmCharts/portfolio/templates/sealed-secret.yaml` with a real `kubeseal` output that contains SMTP_USER/SMTP_PASS/RECIPIENT_EMAIL, so the Secret materializes in-cluster and `envFrom` has data.

### Checkpoint H-3: End-to-end cutover verification (Plan 03-06 Task 4)
After H-1 + Flux reconcile (~10m):
```
kubectl -n portfolio get helmrelease portfolio           # Ready, REVISION 0.2.0
kubectl -n portfolio get pods                             # 2x portfolio-api, 2x portfolio-web only
kubectl -n portfolio get secret portfolio-smtp            # exists (materialized)
kubectl -n portfolio get authorizationpolicy portfolio-api-allow
kubectl -n portfolio exec deploy/portfolio-web -c web -- wget -qO- http://portfolio-api.portfolio.svc.cluster.local:5000/health
```
Istio ingress gateway SA name assumption (`istio-ingressgateway-service-account`) must be confirmed in-cluster — if the install used a non-default name, update `portfolio/base/authorizationpolicy.yaml` principal.

## Requirements Satisfied

- **DEP-01 deployment**: chart templates now deploy portfolio-web + portfolio-api on correct ports with probes and resources.
- **DEP-02 traffic**: VirtualService routes `/api` -> portfolio-api:5000, `/` -> portfolio-web:3000.
- **DEP-03 GitOps**: Flux HelmRelease + HelmRepository wired; image-automation markers preserved.
- **DEP-04 retirement**: Old FastAPI/EJS trees deleted; chart only renders new workloads.
- **DEP-05 health**: Both probes hit `/health`; live/ready on correct ports.
- **SEC-01 CORS**: `ALLOWED_ORIGINS` pinned to `https://yedressov.com,http://localhost:3000`.
- **SEC-03 secrets**: No plaintext SMTP in values.yaml or HelmRelease; `envFrom: secretRef: portfolio-smtp` only.
- **SEC-04 PSS-Restricted**: Both pods preserve runAsNonRoot, readOnlyRootFilesystem, drop ALL caps, seccomp RuntimeDefault.
- **SEC-06 layered defense**: NetworkPolicy (L3/4) + Istio AuthorizationPolicy (L7 / mTLS principal).
- **CI-04 chart push**: helmchart.yaml produces an immutable-tagged OCI push on chart changes.

## Self-Check: PASSED

Verified:
- `helm lint HelmCharts/portfolio` — 0 failures
- `helm template HelmCharts/portfolio` — renders clean; contains `containerPort: 5000`, `path: /health`, `name: portfolio-smtp`, `serviceAccountName: portfolio-api`, `serviceAccountName: portfolio-web`, no `portfolio-frontend` / `path: /api/health` references
- `kubectl kustomize portfolio/base` — renders 8 resource kinds (Namespace, HelmRepository, HelmRelease, VirtualService, 2 NetworkPolicies, AuthorizationPolicy, Kustomization) with zero errors
- `! test -d app/backend && ! test -d app/frontend` — pass
- Commits b37fd3c, f4a3aeb, fda2a2c, b1491ca, 015061e, 26f8197 all present in `git log --oneline`
