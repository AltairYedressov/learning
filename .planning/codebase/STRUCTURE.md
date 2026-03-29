# Codebase Structure

**Analysis Date:** 2026-03-28

## Directory Layout

```
learning/
├── app/                                 # Two-tier portfolio application
│   ├── backend/                         # Python FastAPI backend service
│   │   ├── main.py                      # FastAPI application with endpoints
│   │   ├── requirements.txt             # Python dependencies (fastapi, uvicorn, pydantic)
│   │   └── Dockerfile                   # Multi-stage build for backend container
│   ├── frontend/                        # Node.js Express frontend service
│   │   ├── src/
│   │   │   └── server.js                # Express server, EJS templating, API calls
│   │   ├── views/
│   │   │   ├── index.ejs                # Main portfolio HTML template
│   │   │   └── error.ejs                # Error page fallback
│   │   ├── public/                      # Static assets (CSS, JS, images)
│   │   ├── package.json                 # Node.js dependencies (express, axios, ejs)
│   │   └── Dockerfile                   # Multi-stage build for frontend container
│   └── README.md                        # App documentation, deployment instructions
│
├── HelmCharts/                          # Helm chart repository for portfolio app
│   └── portfolio/
│       ├── Chart.yaml                   # Chart metadata (name, version, description)
│       ├── values.yaml                  # Default Helm values (replicas, images, ports, resources)
│       └── templates/
│           ├── 01-backend.yaml          # Backend Deployment + ClusterIP Service
│           └── 02-frontend.yaml         # Frontend Deployment + ClusterIP Service + env vars
│
├── portfolio/                           # FluxCD-managed portfolio app configuration
│   ├── base/                            # Base configuration (applied to all environments)
│   │   ├── namespace.yaml               # portfolio namespace with istio-injection: enabled
│   │   ├── helmrepository.yaml          # Points to ECR OCI Helm repository
│   │   ├── helmrelease.yaml             # Flux HelmRelease for portfolio app (defines image tags, replicas, resources)
│   │   ├── virtualservice.yaml          # Istio VirtualService (routing /api → backend, else → frontend)
│   │   └── kustomization.yaml           # Kustomize manifest list
│   └── overlays/
│       └── dev/
│           ├── kustomization.yaml       # Dev-specific overlays
│           └── patch.yaml               # Dev patches (e.g., lower replicas)
│
├── platform-tools/                      # Kubernetes platform services (observability, security, scaling)
│   ├── istio/                           # Service mesh configuration (traffic routing, mTLS, ingress)
│   │   ├── istio-system/
│   │   │   ├── base/
│   │   │   │   ├── helmrelease.yaml     # HelmRelease for istio-base (CRDs) + istiod (control plane)
│   │   │   │   ├── helmrepository.yaml  # Istio Helm repository
│   │   │   │   ├── namespace.yaml
│   │   │   │   └── kustomization.yaml
│   │   │   └── overlays/
│   │   │       ├── dev/                 # 1 replica, debug logging
│   │   │       └── prod/                # 2 replicas, warning logging
│   │   └── istio-ingress/
│   │       ├── base/
│   │       │   ├── helmrelease.yaml     # HelmRelease for Envoy gateway pods + NLB Service
│   │       │   ├── gateway.yaml         # Gateway CRD (ports 8080 HTTP redirect + 8443 HTTPS)
│   │       │   ├── helmrepository.yaml
│   │       │   ├── namespace.yaml
│   │       │   └── kustomization.yaml
│   │       └── overlays/
│   │           ├── dev/                 # 1 replica, dev ACM cert ARN
│   │           └── prod/                # 2 replicas, prod ACM cert ARN
│   │
│   ├── aws-lb-controller/               # AWS Load Balancer Controller (provisions NLBs/ALBs)
│   │   ├── base/
│   │   │   ├── helmrelease.yaml         # HelmRelease for AWS LB Controller
│   │   │   ├── helmrepository.yaml      # eks-charts repository
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── dev/                     # 1 replica, lower resources
│   │       └── prod/                    # 2 replicas, higher resources
│   │
│   ├── karpenter/                       # Kubernetes autoscaler for node scaling
│   │   ├── base/
│   │   │   ├── helmrelease.yaml         # HelmRelease for Karpenter
│   │   │   ├── provisioner.yaml         # Karpenter provisioner config (Spot instances, consolidation)
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── dev/
│   │       └── prod/
│   │
│   ├── velero/                          # Kubernetes backup and disaster recovery
│   │   ├── base/
│   │   │   ├── helmrelease.yaml         # HelmRelease for Velero
│   │   │   ├── schedule.yaml            # Daily backup schedule
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── dev/                     # 30-day retention
│   │       └── prod/                    # 90-day retention
│   │
│   ├── sealed-secrets/                  # Secret encryption in Git
│   │   ├── base/
│   │   │   ├── helmrelease.yaml         # HelmRelease for Sealed Secrets controller
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── dev/
│   │       └── prod/
│   │
│   ├── efk-logging/                     # Elasticsearch, Filebeat, Kibana stack
│   │   ├── base/
│   │   │   ├── helmrelease.yaml         # HelmRelease for EFK stack
│   │   │   ├── configmap.yaml           # Filebeat config (log shipping)
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── dev/
│   │       └── prod/
│   │
│   ├── eks-monitoring/                  # Prometheus, Grafana, Alertmanager
│   │   ├── base/
│   │   │   ├── helmrelease.yaml         # HelmRelease for kube-prometheus-stack
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── dev/
│   │       └── prod/
│   │
│   └── thanos/                          # Long-term Prometheus metrics storage
│       ├── base/
│       │   ├── helmrelease.yaml         # HelmRelease for Thanos
│       │   └── kustomization.yaml
│       └── overlays/
│           ├── dev/                     # S3 backend storage
│           └── prod/
│
├── terraform-infra/                     # Infrastructure as Code (AWS provisioning)
│   ├── bootstrap/                       # One-time setup (Terraform state S3 bucket, DynamoDB)
│   │   ├── main.tf
│   │   ├── backend.tf
│   │   └── outputs.tf
│   │
│   ├── database/                        # Reusable RDS module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── iam-role-module/                 # Reusable IAM role module
│   │   ├── main.tf                      # Creates IAM role with trust policy
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── Policies/
│   │       ├── aws_lb_controller_policy.json    # LB controller permissions
│   │       ├── karpenter_policy.json           # Karpenter autoscaler permissions
│   │       ├── velero_policy.json              # Velero backup permissions
│   │       └── thanos_policy.json              # Thanos metrics storage permissions
│   │
│   ├── networking/                      # Reusable networking module
│   │   ├── vpc-module/                  # VPC CIDR, DNS settings
│   │   ├── subnets/                     # Public + private subnets
│   │   ├── igw/                         # Internet Gateway
│   │   ├── route-tables/                # Public/private routing
│   │   └── security-group/              # Security groups (cluster, workers, database)
│   │
│   ├── dns/                             # Route53 and ACM configuration
│   │   └── acm/                         # SSL certificate in ACM
│   │
│   ├── ecr/                             # Elastic Container Registry
│   │   └── main.tf                      # Creates ECR repositories for images/portfolio-backend, images/portfolio-frontend
│   │
│   ├── s3/                              # S3 buckets (Velero backups, Thanos metrics)
│   │   └── main.tf
│   │
│   └── root/                            # Root workspaces (combine modules with actual values)
│       ├── dev/                         # Dev environment configuration
│       │   ├── networking/
│       │   │   └── main.tf              # Calls networking module, creates inter-SG rules
│       │   ├── iam-roles/
│       │   │   ├── main.tf              # Creates 6 IRSA roles
│       │   │   ├── variables.tf         # Role names, policy ARNs
│       │   │   └── data-blocks.tf       # Looks up EKS OIDC provider
│       │   ├── s3/
│       │   │   └── main.tf              # Creates S3 buckets for Velero + Thanos
│       │   ├── eks/
│       │   │   ├── main.tf              # EKS cluster, node groups, Flux CD bootstrap
│       │   │   ├── variables.tf
│       │   │   └── outputs.tf
│       │   ├── database/
│       │   │   └── main.tf              # RDS MySQL instance
│       │   ├── ecr/
│       │   │   └── main.tf              # ECR repositories
│       │   ├── dns/
│       │   │   ├── main.tf              # Route53 A record for yedressov.com
│       │   │   └── variables.tf         # Domain name, NLB hostname
│       │   └── README.md                # Full stack architecture documentation
│       └── prod/                        # Prod environment (same structure as dev)
│
├── clusters/                            # Flux CD cluster configuration
│   ├── dev-projectx/                    # Dev EKS cluster state
│   │   ├── flux-system/                 # Flux CD bootstrap manifests
│   │   │   ├── gotk-sync.yaml           # GitRepository + Kustomization for flux-system
│   │   │   ├── gotk-components.yaml     # Flux CD component images
│   │   │   └── kustomization.yaml
│   │   ├── portfolio.yaml               # Kustomization pointing to portfolio/base
│   │   ├── istio.yaml                   # Kustomization pointing to platform-tools/istio overlays
│   │   ├── aws-lb-controller.yaml       # Kustomization for LB controller
│   │   ├── karpenter.yaml
│   │   ├── velero.yaml
│   │   ├── sealed-secrets.yaml
│   │   ├── efk-logging.yaml
│   │   ├── eks-monitoring.yaml
│   │   ├── thanos.yaml
│   │   └── monitoring.yaml
│   └── test/                            # Test cluster (similar structure)
│       └── flux-system/
│
├── .github/                             # GitHub configuration
│   ├── workflows/                       # CI/CD automation
│   │   ├── image.yaml                   # Docker build + push to ECR on app/ changes
│   │   ├── helmchart.yaml               # Helm chart push to ECR on HelmCharts/ changes
│   │   ├── deploy-workflow.yaml         # Terraform plan/apply on feature/main branches
│   │   ├── validation-PT.yaml           # Helm chart linting
│   │   └── README.md                    # Workflow documentation
│   └── README.md
│
├── scripts/                             # Helper scripts
│   ├── setup.sh                         # Bootstrap cluster setup
│   └── ...
│
├── .planning/                           # GSD planning documents
│   └── codebase/                        # Architecture and structure analysis
│       ├── ARCHITECTURE.md              # Layer breakdown, data flow, abstractions
│       └── STRUCTURE.md                 # This file
│
├── .gitignore
├── README.md                            # Project root documentation
└── SECURITY-AUDIT.md                    # Security analysis and recommendations
```

## Directory Purposes

**app/:**
Purpose: Two-tier portfolio application (frontend + backend)
Contains: Node.js/Express frontend, Python/FastAPI backend, Docker configurations
Key files: `app/frontend/src/server.js`, `app/backend/main.py`

**HelmCharts/portfolio/:**
Purpose: Helm chart template for portfolio app (reusable, parameterized)
Contains: Deployment/Service templates with variable substitution
Key files: `HelmCharts/portfolio/templates/01-backend.yaml`, `02-frontend.yaml`

**portfolio/:**
Purpose: FluxCD-managed portfolio app configuration (Git-sourced, automatically reconciled)
Contains: Namespace, HelmRelease (deployment spec + image tags), VirtualService (routing)
Key files: `portfolio/base/helmrelease.yaml`, `virtualservice.yaml`

**platform-tools/:**
Purpose: Platform services for observability, security, scaling, ingress, backup
Contains: Kustomize-based deployments for Istio, Karpenter, Velero, EFK, Thanos, Sealed Secrets
Key files: `platform-tools/istio/istio-ingress/base/gateway.yaml` (routes external traffic)

**terraform-infra/:**
Purpose: Infrastructure as Code for AWS (VPC, EKS, IAM, RDS, S3, DNS)
Contains: Reusable modules + root workspaces combining modules with env-specific values
Key files: `terraform-infra/root/dev/eks/main.tf` (EKS cluster), `iam-roles/main.tf` (IRSA)

**clusters/:**
Purpose: GitOps source of truth for Flux CD reconciliation
Contains: Kustomization manifests that reference platform-tools overlays and portfolio config
Key files: `clusters/dev-projectx/portfolio.yaml`, `istio.yaml` (dependency chains)

**.github/workflows/:**
Purpose: CI/CD automation (build, push, deploy)
Contains: GitHub Actions workflows for Docker image push, Helm chart push, Terraform deploy
Key files: `image.yaml` (app builds), `helmchart.yaml` (chart uploads), `deploy-workflow.yaml` (infra)

## Key File Locations

**Entry Points:**

- `app/frontend/src/server.js`: Express server (port 3000), fetches from backend API
- `app/backend/main.py`: FastAPI server (port 8000), serves resume data
- `terraform-infra/root/dev/eks/main.tf`: EKS cluster creation, Flux CD bootstrap
- `clusters/dev-projectx/flux-system/gotk-sync.yaml`: Flux reconciliation root (points to `./clusters/dev-projectx`)

**Configuration:**

- `portfolio/base/helmrelease.yaml`: Defines image tags, replicas, resource limits, environment variables
- `HelmCharts/portfolio/values.yaml`: Default Helm values (replicated in helmrelease)
- `terraform-infra/root/dev/README.md`: Stack overview, deployment order, variable descriptions
- `.github/workflows/image.yaml`: Docker build matrix, ECR registry configuration

**Core Logic:**

- `app/backend/main.py`: Pydantic models (Profile, Skill, Experience), FastAPI endpoints
- `app/frontend/src/server.js`: Express routing, Axios API client, EJS template rendering
- `platform-tools/istio/istio-ingress/base/gateway.yaml`: Istio Gateway (ports 8080/8443, hosts)
- `portfolio/base/virtualservice.yaml`: Route rules (URI prefix matching to services)

**Testing & Validation:**

- `.github/workflows/validation-PT.yaml`: Helm chart linting (helm lint)
- `.github/workflows/deploy-workflow.yaml`: Terraform fmt -check, validate, plan

## Naming Conventions

**Files:**

- Kubernetes manifests: `NN-resource-type.yaml` (e.g., `00-namespace.yaml`, `01-backend.yaml`)
- Terraform: `main.tf`, `variables.tf`, `outputs.tf`, `backend.tf`, `providers.tf`, `data-blocks.tf`
- Helm charts: `Chart.yaml`, `values.yaml`, `templates/` subdirectory
- GitHub Actions: Descriptive names with `.yaml` extension (e.g., `image.yaml`, `deploy-workflow.yaml`)

**Directories:**

- Platform tools: `platform-tools/{tool-name}/base/`, `platform-tools/{tool-name}/overlays/{env}/`
- Environment workspaces: `terraform-infra/root/{dev,prod,stage}/`
- Cluster configs: `clusters/{cluster-name}/`
- Helm repositories: `HelmCharts/{chart-name}/`

**Kubernetes Resources:**

- Deployments: kebab-case (e.g., `portfolio-api`, `portfolio-frontend`, `aws-load-balancer-controller`)
- Services: match deployment name (e.g., `portfolio-api`, `portfolio-frontend`)
- Namespaces: lowercase (e.g., `portfolio`, `istio-system`, `istio-ingress`, `karpenter`, `kube-system`)
- Labels: `app: portfolio-api`, `tier: backend`, `istio: ingress`

## Where to Add New Code

**New Application Feature (Frontend or Backend):**
- Frontend code: `app/frontend/src/` (Express routes), `app/frontend/views/` (EJS templates)
- Backend code: `app/backend/main.py` (FastAPI endpoints, Pydantic models)
- Dockerfile: Update `app/frontend/Dockerfile` or `app/backend/Dockerfile` if dependencies change
- Helm values: Update `HelmCharts/portfolio/values.yaml` if new env vars or ports needed
- Tests: Create `app/frontend/*.test.js` or `app/backend/*.py` test files

**New Platform Service:**
- Service kustomize structure: Create `platform-tools/{service-name}/base/` with `helmrelease.yaml`, `helmrepository.yaml`, `kustomization.yaml`
- Environment overlays: `platform-tools/{service-name}/overlays/{dev,prod}/patch.yaml`
- Cluster reference: Add Kustomization in `clusters/dev-projectx/{service-name}.yaml`
- IAM/secrets: Update `terraform-infra/root/dev/iam-roles/main.tf` if service needs AWS permissions

**New Infrastructure Module:**
- Module structure: `terraform-infra/{module-name}/main.tf`, `variables.tf`, `outputs.tf`
- Root workspace usage: Call module in `terraform-infra/root/dev/{domain}/main.tf`
- Reusable: Design module to work across dev/prod (parameterize via variables)

**New Kubernetes Custom Resource:**
- Location: Appropriate platform tool directory (e.g., Karpenter provisioner in `platform-tools/karpenter/base/`)
- Include in kustomization: Add to `kustomization.yaml` resources list
- Reference in cluster: Add to `clusters/dev-projectx/` Kustomization if cluster-level

**Utilities & Helpers:**
- Shared scripts: `scripts/` directory (bash, python, terraform scripts)
- Documentation: Place in `README.md` files alongside code, or top-level `SECURITY-AUDIT.md`

## Special Directories

**terraform-infra/bootstrap/:**
Purpose: One-time infrastructure setup (S3 state bucket, DynamoDB lock table)
Generated: No (manually managed)
Committed: Yes (checked into Git)

**.terraform/:**
Purpose: Terraform plugin cache and state (DO NOT COMMIT)
Generated: Yes (by terraform init)
Committed: No (in .gitignore)

**node_modules/ (app/frontend/):**
Purpose: Installed Node.js packages
Generated: Yes (by npm install)
Committed: No (in .gitignore)

**.git/:**
Purpose: Git repository metadata
Generated: Yes (by git init)
Committed: N/A

**.github/workflows/ output logs:**
Purpose: GitHub Actions run artifacts (not in repo)
Generated: Yes (by GitHub)
Committed: No

---

*Structure analysis: 2026-03-28*
