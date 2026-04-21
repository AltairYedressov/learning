# Codebase Structure

**Analysis Date:** 2026-04-15

## Directory Layout

```
learning/
├── .github/workflows/                # GitHub Actions CI/CD workflows
├── .planning/codebase/               # GSD analysis documents (this directory)
├── app/                              # Application code
│   ├── frontend/src/server.js        # Express web server (port 3000)
│   ├── frontend/views/               # EJS templates
│   ├── frontend/public/              # Static assets
│   ├── frontend/Dockerfile
│   ├── backend/main.py               # FastAPI API (port 8000)
│   ├── backend/tests/
│   └── backend/Dockerfile
├── HelmCharts/portfolio/             # Helm chart
│   ├── Chart.yaml
│   └── templates/                    # 01-backend.yaml, 02-frontend.yaml
├── portfolio/                        # Application Kustomization (GitOps)
│   ├── base/
│   │   ├── helmrelease.yaml          # HelmRelease CRD (entry point)
│   │   ├── virtualservice.yaml       # Istio routing rules
│   │   └── ...
│   └── overlays/dev/
├── clusters/dev-projectx/            # Flux CD Kustomizations (Git SSOT)
│   ├── portfolio.yaml                # Points to ./portfolio/base
│   ├── istio.yaml
│   ├── eks-monitoring.yaml
│   └── ...
├── platform-tools/                   # Kubernetes cluster tools
│   ├── istio/
│   ├── eks-monitoring/               # Prometheus, Grafana
│   ├── efk-logging/                  # Fluent Bit, Elasticsearch, Kibana
│   ├── karpenter/                    # Node autoscaler
│   ├── velero/
│   ├── sealed-secrets/
│   ├── thanos/
│   ├── aws-lb-controller/
│   └── ...
├── terraform-infra/                  # Infrastructure as Code
│   ├── bootstrap/                    # S3 state bucket
│   ├── root/dev/                     # Dev environment root workspace
│   │   ├── networking/
│   │   ├── iam-roles/
│   │   ├── eks/                      # EKS cluster
│   │   ├── database/
│   │   ├── s3/
│   │   ├── ecr/
│   │   ├── dns/
│   │   ├── backend.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   └── main.tf
│   ├── root/prod/
│   ├── eks-cluster/                  # Reusable EKS module
│   ├── networking/                   # Reusable VPC module
│   ├── iam-role-module/
│   └── ...
├── scripts/
├── .gitignore
├── CLAUDE.md                         # Project instructions
└── README.md
```

## Directory Purposes

**`app/frontend/`:** Node.js Express web server serving portfolio (port 3000)
- Entry point: `app/frontend/src/server.js`
- Add new feature: Update route handler, add EJS template in `app/frontend/views/`

**`app/backend/`:** Python FastAPI REST API serving resume data (port 8000)
- Entry point: `app/backend/main.py`
- Add new endpoint: Add Pydantic model + `@app.get()` handler

**`HelmCharts/portfolio/`:** Helm chart for application deployment
- Key files: `Chart.yaml`, `templates/01-backend.yaml`, `templates/02-frontend.yaml`
- Rendered by HelmRelease in `portfolio/base/helmrelease.yaml`

**`portfolio/base/`:** Base Kustomization manifests applied to all environments
- Key file: `helmrelease.yaml` (defines which Helm chart to deploy + values)
- Key file: `virtualservice.yaml` (Istio routing: /api → backend, else → frontend)

**`clusters/dev-projectx/`:** Flux CD Kustomizations - Git source of truth for cluster state
- Each YAML file points to a Git path (e.g., `portfolio.yaml` → `./portfolio/base`)
- Flux reconciles every 10 minutes

**`platform-tools/`:** Kubernetes cluster-wide operational tools
- Structure: `base/` (core) + `overlays/dev,prod/` (environment patches)
- Tools: Istio (ingress), EFK (logging), Prometheus/Grafana (monitoring), Karpenter (autoscaling), Velero (backup), sealed-secrets, Thanos, AWS LB Controller, Kyverno

**`terraform-infra/root/dev/`:** Development infrastructure root workspace
- Orchestrates modules: networking, iam-roles, eks, database, s3, ecr, dns
- Key files: `backend.tf` (S3 state), `providers.tf` (auth), `main.tf` (module calls)

**`terraform-infra/eks-cluster/`:** Reusable EKS module
- Creates cluster, worker nodes, OIDC provider, Flux bootstrap

**`terraform-infra/iam-role-module/`:** Reusable IAM role module
- Creates roles with least-privilege policies

## Key File Locations

**Entry Points:**
- `app/frontend/src/server.js` - Express (port 3000)
- `app/backend/main.py` - FastAPI (port 8000)
- `terraform-infra/root/dev/` - Terraform root workspace
- `clusters/dev-projectx/` - Flux CD Kustomizations

**Configuration & Deployment:**
- `portfolio/base/helmrelease.yaml` - Helm chart deployment (image tags, resource limits)
- `portfolio/base/virtualservice.yaml` - Istio routing rules
- `HelmCharts/portfolio/Chart.yaml` - Helm chart metadata

**Core Application Logic:**
- `app/backend/main.py` - FastAPI endpoints, Pydantic models, middleware
- `app/frontend/src/server.js` - Express routing, backend API calls, template rendering

**Infrastructure:**
- `terraform-infra/root/dev/networking/main.tf` - VPC, subnets, security groups
- `terraform-infra/root/dev/iam-roles/main.tf` - IAM roles
- `terraform-infra/root/dev/eks/main.tf` - EKS cluster
- `terraform-infra/root/dev/database/main.tf` - RDS/Aurora
- `terraform-infra/root/dev/ecr/main.tf` - ECR repositories
- `terraform-infra/root/dev/dns/main.tf` - Route53, ACM

**Platform Tools:**
- `platform-tools/istio/istio-ingress/base/gateway.yaml` - Envoy Gateway
- `platform-tools/eks-monitoring/base/helmrelease.yaml` - Prometheus/Grafana
- `platform-tools/efk-logging/base/helmrelease.yaml` - Fluent Bit/Elasticsearch/Kibana
- `platform-tools/karpenter/base/` - Node autoscaler

## Naming Conventions

**Files:**
- JavaScript: camelCase (`server.js`) or kebab-case (`.eslintrc`)
- Python: lowercase_with_underscores (`main.py`, `requirements.txt`)
- Terraform: lowercase_with_underscores (`main.tf`, `variables.tf`, `outputs.tf`)
- YAML/Kubernetes: lowercase with hyphens (`virtualservice.yaml`, `network-policy.yaml`)

**Kubernetes Resources:**
- Names: lowercase kebab-case (`portfolio-api`, `portfolio-frontend`)
- Namespaces: lowercase (`portfolio`, `istio-system`, `flux-system`)
- Labels: `app: portfolio-api`, `tier: backend`, `environment: dev`

**Terraform Resources:**
- Variables: UPPER_CASE (`ACCOUNT_ID`, `CLUSTER_NAME`)
- Resource names: lowercase_with_underscores (`aws_eks_cluster.projectx_cluster`)

**Docker Images:**
- Path: `ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/images/SERVICE_NAME:TAG`
- Example: `372517046622.dkr.ecr.us-east-1.amazonaws.com/images/portfolio-backend:5e83c60`

## Where to Add New Code

**New API Endpoint:**
1. Add Pydantic model in `app/backend/main.py`
2. Add `@app.get()` handler in `app/backend/main.py`
3. Call from frontend: Update `app/frontend/src/server.js` route handler
4. Add tests: Create `app/backend/tests/test_[module].py`

**New Frontend Component:**
- Template: `app/frontend/views/[component].ejs`
- Styles: `app/frontend/public/css/[component].css`
- Scripts: `app/frontend/public/js/[script].js`

**New Kubernetes Platform Tool:**
- Create: `platform-tools/[tool-name]/base/` + `overlays/dev,prod/`
- Reference: Add `clusters/dev-projectx/[tool-name].yaml` (Kustomization)

**New AWS Infrastructure (Terraform):**
- Create module: `terraform-infra/[resource-type]/` with `main.tf`, `variables.tf`, `outputs.tf`
- Call in root: Add to `terraform-infra/root/dev/[resource-type]/main.tf`

**New Environment (Dev → Prod):**
- Create root: `terraform-infra/root/prod/` (mirror dev)
- Create cluster config: `clusters/prod-projectx/` (mirror dev-projectx)

## Special Directories

**`.git/`:** Git repository metadata (auto-managed, not committed)

**`.pytest_cache/`, `__pycache__/`:** Python cache (auto-created, gitignored)

**`.terraform/`:** Terraform plugins (auto-created, gitignored)

**`.terraform.lock.hcl`:** Terraform dependency lock (auto-created, committed)

**`terraform.tfstate*`:** Terraform state (stored in S3 backend, not committed)

**`clusters/dev-projectx/flux-system/`:** Flux bootstrap manifests (auto-generated, committed)

**`node_modules/`, `site-packages/`:** Dependencies (auto-created, gitignored)

---

*Structure analysis: 2026-04-15*
