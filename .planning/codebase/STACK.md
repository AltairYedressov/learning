# Technology Stack

**Analysis Date:** 2026-03-28

## Languages

**Primary:**
- JavaScript (Node.js 20) - Frontend server and application logic
- Python 3.12 - Backend API server and business logic

**Secondary:**
- HCL (Terraform) - Infrastructure as Code for AWS provisioning
- YAML - Kubernetes manifests, Helm charts, and FluxCD GitOps definitions

## Runtime

**Environment:**
- Node.js 20 (Alpine Linux base for production containers)
- Python 3.12 (slim Linux base for production containers)
- Kubernetes (EKS on AWS) - Orchestration and deployment platform

**Package Manager:**
- npm - JavaScript dependencies
- pip - Python dependencies
- Terraform (version ~6.0) - Infrastructure provisioning

## Frameworks

**Core:**
- Express 4.21.0 - Frontend web server and HTTP routing (`/Users/altairyedressov/School/finale/learning/app/frontend/src/server.js`)
- FastAPI 0.115.0 - Backend REST API and data endpoints (`/Users/altairyedressov/School/finale/learning/app/backend/main.py`)
- Uvicorn 0.30.0 - ASGI application server for FastAPI

**Templating:**
- EJS 3.1.10 - Server-side template rendering for HTML views (`/Users/altairyedressov/School/finale/learning/app/frontend/views`)

**Infrastructure & Orchestration:**
- Helm v3 - Kubernetes package management (`/Users/altairyedressov/School/finale/learning/HelmCharts/portfolio`)
- FluxCD 1.8 - GitOps continuous deployment and cluster reconciliation (`/Users/altairyedressov/School/finale/learning/clusters`)
- Kustomize - Kubernetes manifest customization and overlays
- Istio - Service mesh for traffic management and ingress routing

**Build & Deployment:**
- Docker - Containerization for both frontend and backend services
- Terraform 6.33.0 - Infrastructure provisioning on AWS
- GitHub Actions - CI/CD pipeline orchestration

## Key Dependencies

**Critical:**
- axios 1.7.0 - HTTP client for frontend to call backend API (`/Users/altairyedressov/School/finale/learning/app/frontend/src/server.js`)
- pydantic 2.9.0 - Data validation and serialization for FastAPI models (`/Users/altairyedressov/School/finale/learning/app/backend/main.py`)

**Infrastructure:**
- AWS Provider (Terraform ~6.0) - Cloud infrastructure provisioning
- Flux Provider (Terraform ~1.8) - GitOps automation in Kubernetes
- GitHub Provider (Terraform ~6.11) - GitHub integration for Flux CD
- Kubernetes Provider (Terraform ~2.38) - Kubernetes cluster management

## Configuration

**Environment:**
- Frontend configuration via environment variables:
  - `PORT` - Express server port (default: 3000)
  - `API_URL` - Backend API endpoint (default: http://localhost:8000)
- Backend configuration via FastAPI automatic documentation
- Infrastructure configuration via Terraform variables in `terraform-infra/` modules

**Build:**
- `Dockerfile` in `/Users/altairyedressov/School/finale/learning/app/frontend` - Builds Node.js 20 Alpine image
- `Dockerfile` in `/Users/altairyedressov/School/finale/learning/app/backend` - Builds Python 3.12 slim image
- Helm values defined in chart templates (`/Users/altairyedressov/School/finale/learning/HelmCharts/portfolio/Chart.yaml`)

## Platform Requirements

**Development:**
- Docker (for local containerization)
- Node.js 20 (for frontend development)
- Python 3.12 (for backend development)
- Terraform (for infrastructure changes)
- kubectl (for Kubernetes cluster interaction)
- Helm (for chart management)

**Production:**
- AWS EKS cluster (Kubernetes managed service on AWS)
- AWS RDS or Aurora database (provisioned via Terraform in `terraform-infra/database/`)
- AWS S3 for object storage (provisioned in `terraform-infra/s3/`)
- AWS ECR for container image registry
- AWS VPC with networking (defined in `terraform-infra/networking/`)
- Kubernetes nodes managed via Karpenter autoscaling

---

*Stack analysis: 2026-03-28*
