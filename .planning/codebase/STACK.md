# Technology Stack

**Analysis Date:** 2026-04-15

## Languages

**Primary:**
- JavaScript (Node.js 20) - Frontend Express server and routing (`app/frontend/src/server.js`)
- Python 3.12 - Backend FastAPI REST API and business logic (`app/backend/main.py`)
- HCL (Terraform) - Infrastructure as Code for AWS provisioning (`terraform-infra/`)
- YAML - Kubernetes manifests, Helm charts, and FluxCD GitOps definitions (`HelmCharts/`, `clusters/`, `platform-tools/`)
- Shell - Bootstrap and deployment scripts

**Secondary:**
- Go - Underlying language for Istio control plane and Envoy proxy (installed via Helm)

## Runtime

**Environment:**
- Node.js 20 (Alpine Linux base for production) - Frontend server runtime
- Python 3.12 (Slim Linux base for production) - Backend API runtime
- Kubernetes (EKS on AWS) - Container orchestration and deployment platform
- Docker - Containerization for both frontend and backend services

**Package Managers:**
- npm 10.x (bundled with Node.js 20) - JavaScript dependencies
  - Lockfile: `app/frontend/package-lock.json` (present)
- pip 24.x (bundled with Python 3.12) - Python dependencies
  - Lockfile: `app/backend/requirements.txt` (pinned versions)
- Terraform 1.6.6+ - Infrastructure provisioning and state management

## Frameworks

**Core Application:**
- Express 4.21.0 - Frontend HTTP server, routing, middleware, EJS template rendering (`app/frontend/src/server.js`)
- FastAPI 0.115.0 - Backend REST API with automatic OpenAPI documentation (`app/backend/main.py`)
- Uvicorn 0.30.0 - ASGI application server for FastAPI (async request handling)

**Infrastructure & Orchestration:**
- Helm v3 - Kubernetes package management and templated deployments (`HelmCharts/portfolio/`)
- FluxCD 1.8 - GitOps continuous deployment controller for cluster reconciliation (`clusters/`)
- Kustomize - Kubernetes manifest customization, overlays, and patching (`platform-tools/`, `portfolio/`)
- Istio >=1.24.0 <2.0.0 - Service mesh for traffic management, mTLS, and ingress routing (`platform-tools/istio/`)
- Karpenter - Kubernetes autoscaling controller for cost-optimized node provisioning

**Build & Development:**
- Docker (latest) - Container image building and local development
- GitHub Actions - CI/CD pipeline orchestration (`.github/workflows/`)

## Key Dependencies

**Frontend (`app/frontend/package.json`):**
- express 4.21.0 - Web server framework (critical)
- axios 1.7.0 - HTTP client for backend API calls
- ejs 3.1.10 - Server-side template engine for HTML rendering

**Backend (`app/backend/requirements.txt`):**
- fastapi 0.115.0 - REST API framework with automatic documentation (critical)
- uvicorn[standard] 0.30.0 - ASGI server with HTTP/1.1 and WebSocket support
- pydantic 2.9.0 - Data validation and serialization for request/response models
- slowapi 0.1.9 - Rate limiting middleware (60 requests/minute default)

**Infrastructure & Tooling:**
- AWS Provider (Terraform ~6.0) - Cloud infrastructure provisioning
- Flux Provider (Terraform ~1.8) - GitOps bootstrap and cluster configuration
- GitHub Provider (Terraform ~6.11) - GitHub repository and OIDC provider integration
- Kubernetes Provider (Terraform ~2.38) - Kubernetes resource management

**Platform Tools (Helm Charts):**
- kube-prometheus-stack 58.x.x - Prometheus + Grafana + Alertmanager for monitoring
- Velero 8.1.0 - Cluster and persistent volume backup and disaster recovery
- Elasticsearch 8.5.1 - Distributed search and analytics engine for centralized logging
- Kibana - Visualization and dashboard tool for Elasticsearch logs
- Thanos 15.x.x - Long-term metrics storage (uses S3 backend)
- sealed-secrets - Kubernetes secret encryption at rest
- aws-load-balancer-controller - AWS NLB/ALB controller for Kubernetes services
- karpenter - Kubernetes node autoscaling with spot instance support

## Configuration

**Environment:**
- Frontend environment via variables (`process.env.PORT`, `process.env.API_URL`)
  - Default: PORT=3000, API_URL=http://localhost:8000 (dev)
  - Production: API_URL=https://yedressov.com (from HelmRelease values)
- Backend configuration via Uvicorn CLI args (`--host 0.0.0.0 --port 8000`)
- Infrastructure configuration via Terraform variables (`.tfvars` files in `terraform-infra/root/dev/` and `terraform-infra/root/prod/`)

**Docker Configuration:**
- `app/frontend/Dockerfile` - Node.js 20 Alpine, non-root user (UID 1001), port 3000
- `app/backend/Dockerfile` - Python 3.12 slim, non-root user (UID 1001), port 8000, readOnlyRootFilesystem compatibility

**Kubernetes Configuration:**
- Helm chart values: `HelmCharts/portfolio/values.yaml` (default values for namespace, replicas, resources, images, ports)
- Kustomize overlays: `portfolio/overlays/dev` and `portfolio/overlays/prod` for environment-specific patching
- Security context enforced: runAsNonRoot=true, readOnlyRootFilesystem=true, dropCapabilities=ALL

**Build Configuration:**
- GitHub Actions workflows (`.github/workflows/`)
  - image.yaml - Docker image build, scan (Trivy), and ECR push
  - helmchart.yaml - Helm chart validation and packaging
  - validation-PT.yaml - Terraform plan validation with Flux CD
  - deploy-workflow.yaml - Terraform apply and Flux bootstrap on main branch
- Terraform backends: S3 with encryption and DynamoDB locking (`terraform-infra/root/dev/*/backend.tf`)

## Platform Requirements

**Development:**
- Node.js 20 (local development for frontend)
- Python 3.12 (local development for backend)
- Docker (for containerization and local testing)
- Terraform 1.6.6+ (for infrastructure changes)
- kubectl (for Kubernetes cluster interaction and debugging)
- Helm 3 (for chart management and local testing)
- git (for version control and GitOps)

**Production/Staging:**
- AWS EKS cluster (managed Kubernetes on AWS, version 1.x+)
- AWS RDS or Aurora database (MySQL/PostgreSQL, provisioned in `terraform-infra/database/`)
  - Connection via private subnet, IAM database authentication enabled
  - Multi-AZ, read replicas, cross-region DR replicas supported
  - Automated backups with retention period, blue/green deployments
- AWS S3 buckets (object storage for Terraform state, Velero backups, Thanos metrics)
  - Bucket: `372517046622-terraform-state-dev` (Terraform backend with versioning and encryption)
  - Bucket: `372517046622-velero-backups-dev` (cluster backup storage)
  - Lifecycle policies for cost optimization
- AWS ECR (private container image registry for frontend and backend)
- AWS VPC with public/private subnets (defined in `terraform-infra/networking/`)
  - Internet Gateway for external traffic routing
  - NAT Gateway for outbound traffic from private subnets
  - Network ACLs and security groups for traffic control
- AWS Route53 (DNS with yedressov.com hosted zone)
  - ACM certificate for TLS termination on NLB
  - CNAME records pointing to NLB endpoint
- AWS NLB (Network Load Balancer) with TLS 1.2+ termination
- EKS add-ons: CoreDNS, kube-proxy, VPC CNI, Snapshots, CloudWatch Observability, AWS EBS CSI Driver
- Karpenter for dynamic node provisioning (cost-optimized, spot instance aware)
- OIDC Provider (AWS IAM OpenID Connect) for GitHub Actions OIDC authentication

---

*Stack analysis: 2026-04-15*
