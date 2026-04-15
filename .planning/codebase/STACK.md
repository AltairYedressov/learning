# Technology Stack

**Analysis Date:** 2026-04-15

## Languages

**Primary:**
- JavaScript (Node.js 20) - Frontend HTTP server and API proxy (`app/portfolio/frontend/server.js`)
- Python 3.12 - Backend contact-form API and SMTP sender (`app/portfolio/api/app.py`)
- HCL (Terraform) - Infrastructure as Code for AWS (`terraform-infra/`)
- YAML - Kubernetes manifests, Helm chart templates, FluxCD CRDs, GitHub Actions workflows

**Secondary:**
- Bash - Cluster bootstrap, validation, install helpers (`scripts/*.sh`)
- Dockerfile - Multi-stage container builds (`app/portfolio/{api,frontend}/Dockerfile`)

## Runtime

**Application Runtimes:**
- Node.js 20 on `node:20-alpine` (frontend production image; `app/portfolio/frontend/Dockerfile`)
- Python 3.12 on `python:3.12-slim-bookworm` with virtualenv (backend; `app/portfolio/api/Dockerfile`)
- Gunicorn 23.0.0 (single worker) - WSGI server hosting Flask app at `0.0.0.0:8000`

**Orchestration / Platform:**
- Kubernetes (AWS EKS) - Cluster orchestration (`terraform-infra/eks-cluster/eks.tf`)
- Istio service mesh - Ingress + east-west mTLS (`platform-tools/istio/`)
- FluxCD v2 (kustomize.toolkit + helm.toolkit, source/image automation) - GitOps reconciler

**Package Managers:**
- npm (Node) - Frontend deps; lockfile present at `app/portfolio/frontend/package-lock.json`
- pip (Python) - Backend deps; pinned in `app/portfolio/api/requirements.txt` (no lockfile)
- Helm v3 - Chart packaging (`HelmCharts/portfolio/`)
- Kustomize - Manifest overlays (`portfolio/overlays/`, `platform-tools/*/overlays/`)

## Frameworks

**Frontend (Node):**
- Express 4.21.0 - HTTP server (`app/portfolio/frontend/server.js`)
- http-proxy-middleware 3.0.0 - Reverse-proxy `/api/*` to backend
- helmet 8.0.0 - Security headers + CSP
- compression 1.7.4 - gzip response compression
- dotenv 16.4.5 - Optional local env loading

**Backend (Python):**
- Flask 3.1.1 - REST API framework (`app/portfolio/api/app.py`)
- flask-cors 5.0.1 - CORS handling driven by `ALLOWED_ORIGINS`
- gunicorn 23.0.0 - Production WSGI server
- python-dotenv 1.1.0 - Local env loading
- Standard library `smtplib` + `email.mime` - SMTP STARTTLS email delivery

**Infrastructure / Platform:**
- Terraform >= 1.6.6 (CI uses 1.6.6) - IaC tool (`terraform-infra/root/dev/eks/providers.tf`)
- Helm v3.15.0 (CI pinned) - Kubernetes package manager (`HelmCharts/portfolio/Chart.yaml`)
- FluxCD v2 (`fluxcd/flux` provider `~> 1.8`) - GitOps controller; bootstrapped from Terraform (`terraform-infra/eks-cluster/flux.tf`)
- Istio - Service mesh; HelmRelease in `platform-tools/istio/`
- Karpenter - Node autoscaling (`platform-tools/karpenter/`)
- Sealed Secrets - Encrypted secrets in Git (`platform-tools/sealed-secrets/`)
- Kyverno - Policy engine (`platform-tools/kyverno/`)
- Velero - Backup / DR (`platform-tools/velero/`)
- EFK stack - Logging (`platform-tools/efk-logging/`)
- Thanos + kube-prometheus-stack - Metrics with long-term S3 storage (`platform-tools/thanos/`, `platform-tools/eks-monitoring/`)
- AWS Load Balancer Controller - Provisions NLB for Istio ingress (`platform-tools/aws-lb-controller/`)

**Build / CI Tooling:**
- Docker Buildx + GHA cache (`docker/build-push-action@v6`) - Multi-arch image builds
- Checkov - Terraform IaC security scan (`.github/workflows/deploy-workflow.yaml`)
- Helm lint + helm template - Chart smoke validation in CI

## Key Dependencies

**Critical Application:**
- `express ^4.21.0` - Defines all frontend HTTP routing
- `http-proxy-middleware ^3.0.0` - Sole bridge from web tier to API tier (preserves `/api/*` prefix)
- `helmet ^8.0.0` - Provides CSP locking down `connectSrc` to `BACKEND_URL`
- `flask 3.1.1` + `flask-cors 5.0.1` - Backend API layer with origin allow-list
- `gunicorn 23.0.0` - Production process manager (single worker per pod)

**Critical Infrastructure (Terraform providers, `terraform-infra/eks-cluster/flux.tf`):**
- `hashicorp/aws ~> 6.0` - All AWS resources (EKS, VPC, RDS, S3, IAM, Route53, ACM, ECR)
- `fluxcd/flux ~> 1.8` - Bootstrap Flux into the cluster from Terraform
- `integrations/github ~> 6.11` - Branch protection + Flux Git auth
- `hashicorp/kubernetes ~> 2.38` - In-cluster resources from TF

**EKS Add-ons (versions pinned in `terraform-infra/eks-cluster/addons.tf`):**
- `vpc-cni v1.21.1-eksbuild.3`
- `aws-ebs-csi-driver v1.55.0-eksbuild.2` (IRSA-bound)
- `coredns v1.13.2-eksbuild.1`
- `kube-proxy v1.34.3-eksbuild.2`

## Configuration

**Frontend env vars** (`app/portfolio/frontend/server.js`):
- `PORT` (default `3000`)
- `BACKEND_URL` (default `http://localhost:5000`; production points at K8s service)
- `NODE_ENV` (controls static asset cache headers)

**Backend env vars** (`app/portfolio/api/app.py`):
- `BACKEND_PORT` (default `8000` in container, `5000` locally)
- `MAX_BODY_BYTES` (default `16384`)
- `ALLOWED_ORIGINS` (CSV, default `http://localhost:3000`)
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `RECIPIENT_EMAIL`
- `RATE_LIMIT` (default `5`), `RATE_WINDOW_MINUTES` (default `15`)
- `FLASK_DEBUG` (default `false`)

**Helm chart values** (`HelmCharts/portfolio/values.yaml`, overridden by `portfolio/base/helmrelease.yaml`):
- `images.api`, `images.frontend` - ECR image refs (digest-pinned via Flux image automation)
- `replicas.api`, `replicas.frontend` - default `2`
- `ports.api: 8000`, `ports.frontend: 3000`
- `api.url: http://portfolio-api.portfolio.svc.cluster.local:8000`
- Resource requests `100m / 128Mi`, limits `250m / 256Mi` per container

**Terraform configuration:**
- Backend: S3 (`372517046622-terraform-state-dev`) + DynamoDB lock table (`terraform-infra/root/dev/eks/backend.tf`)
- Per-stack root modules under `terraform-infra/root/dev/{networking,iam-roles,eks,s3,database,ecr,dns}`
- Provider region pinned to `us-east-1`

**Build configuration:**
- `app/portfolio/api/Dockerfile` - Two-stage Python build, non-root uid/gid 10001
- `app/portfolio/frontend/Dockerfile` - Single-stage Node 20 Alpine, non-root uid/gid 10001
- Helm `Chart.yaml` version `0.3.0`, appVersion `0.0.1`

## Platform Requirements

**Development:**
- Docker (local build/test of both images)
- Node.js 20 + npm (frontend)
- Python 3.12 + pip (backend)
- Terraform >= 1.6.6
- kubectl, Helm v3, Kustomize, flux CLI

**Production / Cloud:**
- AWS account `372517046622`, region `us-east-1`
- AWS EKS cluster (managed nodes via ASG, public subnets per project constraint)
- AWS RDS instance (provisioned by `terraform-infra/database/`, master password managed by AWS Secrets Manager)
- AWS S3 (Terraform state bucket + Thanos long-term metric storage)
- AWS ECR (Docker images and OCI Helm charts under `helm-charts/`)
- AWS Route53 + ACM (`terraform-infra/dns/route53`, `terraform-infra/dns/acm`)
- AWS NLB (provisioned by AWS Load Balancer Controller for Istio ingress)
- GitHub repo with OIDC trust to AWS IAM role (`vars.IAM_ROLE`) and PAT secret `FLUX_GITHUB_PAT`

---

*Stack analysis: 2026-04-15*
