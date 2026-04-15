# Architecture

**Analysis Date:** 2026-04-15

## Pattern Overview

**Overall:** Cloud-native two-tier portfolio application running on AWS EKS, provisioned by Terraform and continuously reconciled by FluxCD (GitOps). Istio service mesh provides ingress and east-west traffic; platform tooling is layered via Kustomize bases/overlays.

**Key Characteristics:**
- Strict separation between **infrastructure** (Terraform), **platform** (Flux-managed Kustomize/Helm), and **application** (Helm chart consumed via OCI HelmRelease).
- **GitOps-first**: nothing is deployed by hand to the cluster; the only path to prod is `git push` → Flux reconciliation (10m interval).
- **OIDC everywhere**: GitHub Actions → AWS via OIDC role; pods → AWS via IRSA; no long-lived AWS keys in CI or cluster.
- **Frontend-as-proxy**: Express frontend serves static SPA assets and proxies `/api/*` to a Flask backend over a ClusterIP service (no direct external exposure of API).
- **Image tag automation**: CI publishes images tagged with the commit SHA; HelmRelease values reference the SHA tag (Flux image-automation scaffolding exists under `portfolio/image-automation/base/`).

## Layers

**Layer 1 — Application code (`app/portfolio/`):**
- Purpose: Portfolio website (static SPA + contact-form email API).
- Location: `app/portfolio/frontend/` (Node 20 / Express), `app/portfolio/api/` (Python 3.12 / Flask).
- Contains: `server.js`, `app.py`, Dockerfiles, `public/` static assets, `requirements.txt`, `package.json`.
- Depends on: SMTP relay (Gmail by default) for outbound contact emails.
- Used by: Container builds in `.github/workflows/portfolio-images.yaml`.

**Layer 2 — Application packaging (`HelmCharts/portfolio/`):**
- Purpose: Helm chart that renders Deployments, Services, and SealedSecret for the portfolio app.
- Location: `HelmCharts/portfolio/Chart.yaml`, `HelmCharts/portfolio/templates/`, `HelmCharts/portfolio/values.yaml`.
- Contains: `01-backend.yaml` (api Deployment + ClusterIP), `02-frontend.yaml` (frontend Deployment + ClusterIP), `sealed-secret.yaml` (SMTP creds).
- Depends on: ECR-hosted images, sealed-secrets controller in cluster.
- Used by: `portfolio/base/helmrelease.yaml` HelmRelease (chart pulled from OCI registry).

**Layer 3 — Application GitOps (`portfolio/`):**
- Purpose: Bind the Helm chart to the cluster with environment overlays and ingress routing.
- Location: `portfolio/base/` (HelmRepository, HelmRelease, VirtualService, Namespace), `portfolio/overlays/{dev,prod}/`, `portfolio/image-automation/base/`.
- Contains: `helmrepository.yaml` (OCI ECR), `helmrelease.yaml` (chart version 0.3.0 + values overrides), `virtualservice.yaml` (Istio routing — `/api` → backend, else frontend), `kustomization.yaml`.
- Depends on: ECR HelmRepository, sealed-secrets, Istio Gateway (`istio-ingress/main-gateway`).
- Used by: `clusters/dev-projectx/portfolio.yaml` Flux Kustomization.

**Layer 4 — Platform tools (`platform-tools/`):**
- Purpose: Cluster-wide capabilities (ingress, autoscaling, secrets, backup, logging, metrics, policy).
- Location: `platform-tools/{istio,karpenter,aws-lb-controller,sealed-secrets,velero,efk-logging,thanos,kube-system,kyverno,eks-monitoring}/` each with `base/` + `overlays/{dev,prod}/`.
- Contains: HelmRelease/HelmRepository/Kustomization manifests per tool; istio split into `istio-system` (control plane) and `istio-ingress` (data plane Gateway).
- Depends on: EKS cluster, IAM roles via IRSA, AWS resources (NLB, S3, Route53).
- Used by: All workloads; bound to the cluster by Flux Kustomizations in `clusters/dev-projectx/`.

**Layer 5 — Cluster bindings (`clusters/`):**
- Purpose: Per-cluster Flux Kustomizations declaring which platform tools and apps to install, with explicit `dependsOn` ordering.
- Location: `clusters/dev-projectx/` (live), `clusters/test/` (scaffold), `clusters/dev-projectx/flux-system/` (Flux components + GitRepository).
- Contains: `portfolio.yaml`, `istio.yaml`, `karpenter.yaml`, `aws-lb-controller.yaml`, `sealed-secrets.yaml`, `velero.yaml`, `efk-logging.yaml`, `thanos.yaml`, `kyverno.yaml`, `monitoring.yaml`, `kube-system.yaml`, `flux-system/{gotk-components,gotk-sync,kustomization,networkpolicy,image-automation-sa}.yaml`.
- Depends on: GitRepository `flux-system` pointing at `https://github.com/AltairYedressov/learning` branch `main`.
- Used by: Flux controllers in-cluster.

**Layer 6 — Infrastructure (`terraform-infra/`):**
- Purpose: Provision AWS primitives (VPC, subnets, IGW, SGs, EKS, IAM roles + IRSA, ECR, RDS, S3, Route53, ACM, Flux bootstrap).
- Location: Reusable modules at top level (`networking/`, `eks-cluster/`, `iam-role-module/`, `database/`, `s3/`, `ecr/`, `dns/`, `bootstrap/`); per-environment root workspaces under `terraform-infra/root/{dev,prod}/{networking,iam-roles,s3,ecr,eks,database,dns}/`.
- Contains: `*.tf` per workspace with `main.tf`, `variables.tf`, `providers.tf`, `backend.tf` (S3 remote state); IAM policy JSON in `iam-role-module/Policies/`; Flux GitHub bootstrap in `eks-cluster/flux.tf`.
- Depends on: AWS account (372517046622), GitHub PAT (for Flux bootstrap & branch protection).
- Used by: GitHub Actions Terraform jobs (plan on PR, apply on main).

**Layer 7 — CI/CD (`.github/workflows/`):**
- Purpose: Build/push images, lint+publish Helm chart, plan/apply Terraform.
- Location: `.github/workflows/portfolio-images.yaml`, `helmchart.yaml`, `deploy-workflow.yaml`, `validation-PT.yaml`.
- Contains: Path-filtered triggers, matrix Docker builds, OIDC AWS auth, ECR push, Helm OCI publish.
- Used by: Branch protection (`main`) requires `publish-images` and `terraform (iam-roles)` status checks.

## Data Flow

**Inbound user request (`yedressov.com`):**
1. DNS resolution via Route53 (`terraform-infra/dns/route53/`).
2. AWS NLB (provisioned by AWS Load Balancer Controller from `platform-tools/aws-lb-controller/`).
3. Istio Ingress Gateway (Envoy in `istio-ingress` namespace) terminates TLS using ACM cert.
4. Istio `VirtualService` (`portfolio/base/virtualservice.yaml`) matches host `yedressov.com`:
   - URI prefix `/api` → ClusterIP service `portfolio-api:8000` (Flask).
   - Otherwise → ClusterIP service `portfolio-frontend:3000` (Express, serves SPA + proxies `/api/*` itself if hit directly).
5. Pod-to-pod traffic is auto-mTLS via Istio sidecars.

**Contact form submission:**
1. Browser POSTs to `/api/contact` → frontend (Express) → `http-proxy-middleware` forwards to `BACKEND_URL` (or Istio routes directly via VirtualService).
2. Flask handler in `app/portfolio/api/app.py` validates payload, applies in-memory rate limit (5/15min per IP), sends via SMTP (`smtplib.SMTP`, STARTTLS) using creds from `portfolio-smtp` SealedSecret (`HelmCharts/portfolio/templates/sealed-secret.yaml`).

**GitOps reconciliation:**
1. Developer pushes to `main`.
2. GitHub Actions (`portfolio-images.yaml`) builds + pushes images tagged `${{ github.sha }}` to ECR.
3. `helmchart.yaml` lints and publishes new chart version to `oci://372517046622.dkr.ecr.us-east-1.amazonaws.com/helm-charts/`.
4. Flux GitRepository polls every 1m; root Kustomization (`./clusters/dev-projectx`) reconciles every 10m.
5. Each child Kustomization (`portfolio.yaml`, `istio.yaml`, etc.) reconciles its target path.
6. HelmRelease pulls chart from OCI HelmRepository and runs `helm upgrade --install`.

**Infrastructure provisioning:**
1. Engineer edits `terraform-infra/root/dev/<workspace>/`.
2. PR triggers `terraform plan`; merge triggers `terraform apply` via OIDC-assumed role.
3. State persisted in S3 bucket `372517046622-terraform-state-dev` (provisioned by `bootstrap/`).

## Key Abstractions

**Flux `Kustomization` CRD:**
- Purpose: Bind a path in the repo to the cluster with reconcile interval, prune, and dependency ordering.
- Examples: `clusters/dev-projectx/portfolio.yaml`, `clusters/dev-projectx/istio.yaml`, `clusters/dev-projectx/karpenter.yaml`.
- Pattern: `spec.path: ./<dir>`, `prune: true`, `dependsOn: [...]` to enforce ordering (e.g. `istio-ingress` depends on `istio-system` + `aws-lb-controller`).

**Flux `HelmRelease` + `HelmRepository`:**
- Purpose: Declarative Helm install with values override and auto-rollback.
- Examples: `portfolio/base/helmrelease.yaml` (app), `platform-tools/*/base/helmrelease.yaml` (each tool).
- Pattern: HelmRepository points at OCI ECR (`oci://.../helm-charts/`) with `provider: aws` for IRSA-based auth; HelmRelease pins chart version (e.g. `portfolio` `0.3.0`) and supplies `values:` inline.

**Kustomize `base/` + `overlays/{dev,prod}/`:**
- Purpose: Reusable manifest base with environment-specific patches.
- Examples: `portfolio/base/` + `portfolio/overlays/dev/patch.yaml`, every `platform-tools/*/`.
- Pattern: `overlays/<env>/kustomization.yaml` references `../../base` and applies `patches:`.

**Istio `Gateway` + `VirtualService`:**
- Purpose: Decouple ingress (Gateway listens on host:port with TLS) from routing (VirtualService matches URI prefix).
- Examples: Gateway in `platform-tools/istio/istio-ingress/base/`; VirtualService in `portfolio/base/virtualservice.yaml`.
- Pattern: VirtualService binds to `istio-ingress/main-gateway`, routes by URI prefix to in-mesh ClusterIP services.

**Terraform module + root workspace:**
- Purpose: Reusable infra building blocks consumed by per-environment workspaces.
- Examples: Module `terraform-infra/eks-cluster/` consumed by `terraform-infra/root/dev/eks/main.tf`; module `terraform-infra/iam-role-module/` with policy JSONs in `Policies/`.
- Pattern: Root workspace declares `backend.tf` (S3 state), `providers.tf`, `variables.tf`, and a thin `main.tf` calling `module "<name>" { source = "../../../<module>" ... }`.

**SealedSecret:**
- Purpose: Encrypted-at-rest secret committed to Git; decrypted only by the in-cluster `sealed-secrets` controller.
- Example: `HelmCharts/portfolio/templates/sealed-secret.yaml` (SMTP creds → `portfolio-smtp` Secret consumed by api Deployment via `envFrom.secretRef`).

**Image automation (Flux):**
- Purpose: Auto-bump image tags in Git when a new SHA-tagged image lands in ECR.
- Examples: `portfolio/image-automation/base/{image-repository,image-policy,image-update-automation}-{web,api}.yaml`.

## Entry Points

**Public traffic entry:**
- Location: Route53 hosted zone (`terraform-infra/dns/route53/`) → NLB → `istio-ingress` Gateway.
- Triggers: HTTP/HTTPS request to `yedressov.com`.
- Responsibilities: TLS termination (ACM cert from `terraform-infra/dns/acm/`), Envoy routing.

**Frontend pod:**
- Location: `app/portfolio/frontend/server.js` (started by Dockerfile `CMD`).
- Triggers: Kubelet starts pod from Deployment `portfolio-frontend` (`HelmCharts/portfolio/templates/02-frontend.yaml`).
- Responsibilities: Express on `PORT=3000`, helmet CSP, compression, `/health` (independent of backend), `/api/*` proxy to `BACKEND_URL`, static assets from `public/`, SPA fallback to `public/index.html`.

**Backend pod:**
- Location: `app/portfolio/api/app.py`.
- Triggers: Kubelet starts pod from Deployment `portfolio-api`.
- Responsibilities: Flask on `BACKEND_PORT=5000` (container exposes port 8000 per HelmRelease — values mismatch noted in CONCERNS), `/health` + `/api/health`, `/api/contact` POST handler with rate-limit + SMTP send.

**GitOps entry:**
- Location: `clusters/dev-projectx/flux-system/gotk-sync.yaml` (root GitRepository + Kustomization).
- Triggers: Flux source-controller polls Git every 1m; root reconciles every 10m.
- Responsibilities: Pull `clusters/dev-projectx/` and apply all child Kustomizations.

**CI entry:**
- Location: `.github/workflows/portfolio-images.yaml`, `helmchart.yaml`, `deploy-workflow.yaml`, `validation-PT.yaml`.
- Triggers: `push`/`pull_request` on `main` with path filters.
- Responsibilities: Build & push images, lint & publish chart, plan/apply Terraform via OIDC role `${{ vars.IAM_ROLE }}`.

**Terraform entry:**
- Location: `terraform-infra/root/dev/<workspace>/` and `terraform-infra/root/prod/<workspace>/`.
- Triggers: GitHub Actions Terraform job per workspace.
- Responsibilities: Provision AWS resources, write state to S3.

## Error Handling

**Strategy:** Defense in depth — each layer has its own failure domain and recovery loop.

**Patterns:**
- **Application:** Frontend `/health` is independent of backend reachability (intentional, see comment in `app/portfolio/frontend/server.js`). Backend rejects oversized payloads in `before_request` hook (returns 413 before SMTP touched). Proxy errors return 502 with JSON body.
- **Validation:** Backend validates name/email/subject/message length and email regex before any side effect; rate-limit per IP (5 req / 15 min) returns 429.
- **Kubernetes:** Liveness/readiness probes on `/health` (frontend) and `/api/health` (backend) drive pod restart and service endpoint inclusion.
- **Helm/Flux:** HelmRelease auto-rollback on failed upgrade; Flux Kustomizations have `timeout: 5m` and `dependsOn` to fail fast and respect ordering.
- **Terraform:** Remote state in S3 with branch protection (`required_status_checks`) preventing apply on broken `main`.
- **CI:** `concurrency` group with `cancel-in-progress: false` prevents image-build races.

## Cross-Cutting Concerns

**Logging:**
- App pods write structured-ish logs to stdout (Node `console.*`, Python `logging`).
- EFK stack (`platform-tools/efk-logging/`) collects, indexes, and visualizes (Kibana).
- Istio access logs flow through Envoy sidecars to stdout.

**Metrics & monitoring:**
- `platform-tools/eks-monitoring/` (Prometheus stack) scrapes kubelet, Envoy, app endpoints.
- `platform-tools/thanos/` provides long-term storage in S3 (IRSA via `iam-role-module/Policies/thanos_policy.json`).

**Security:**
- **Identity:** IRSA for in-cluster controllers (Karpenter, AWS LB Controller, Velero, Thanos, image-reflector); GitHub OIDC for CI.
- **Secrets:** SealedSecrets for app secrets in Git; AWS Secrets Manager for RDS password; never `.env` in containers (dotenv `try/catch`).
- **Network:** Istio auto-mTLS east-west; helmet CSP at frontend; security groups in `terraform-infra/networking/security-group/`; Flux NetworkPolicy (`clusters/dev-projectx/flux-system/networkpolicy.yaml`).
- **Policy:** Kyverno (`platform-tools/kyverno/`) enforces cluster-wide admission policies.
- **Supply chain:** Branch protection requires `publish-images` + `terraform (iam-roles)` status checks; image tags are immutable SHAs; chart pinned by version.

**Backup & DR:**
- Velero (`platform-tools/velero/`) snapshots cluster resources/PVs to S3 (IRSA via `velero_policy.json`).

**Autoscaling:**
- Karpenter (`platform-tools/karpenter/`) provisions nodes on-demand; NodePools split into a separate Flux Kustomization (`karpenter-nodepool` `dependsOn: karpenter`).

**Authentication & authorization:**
- EKS access via Access Entries (`terraform-infra/eks-cluster/access-entries.tf`) — `authentication_mode` configurable.
- Cluster API endpoint is `endpoint_public_access = true` (see `terraform-infra/eks-cluster/eks.tf` — flag for security review).

---

*Architecture analysis: 2026-04-15*
