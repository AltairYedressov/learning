# External Integrations

**Analysis Date:** 2026-03-28

## APIs & External Services

**Inter-Service Communication:**
- Portfolio Backend API - REST endpoints serving resume data
  - SDK/Client: axios 1.7.0 (HTTP client in frontend)
  - URL configuration: `API_URL` environment variable
  - Health endpoint: `/api/health` for liveness/readiness checks
  - Data endpoints: `/api/all`, `/api/profile`, `/api/skills`, `/api/experience`, `/api/certifications`, `/api/projects`

**CORS Configuration:**
- FastAPI middleware configured to allow all origins (`allow_origins=["*"]`)
- Location: `/Users/altairyedressov/School/finale/learning/app/backend/main.py` lines 18-24

## Data Storage

**Databases:**
- AWS RDS/Aurora (provisioned via Terraform)
  - Terraform config: `/Users/altairyedressov/School/finale/learning/terraform-infra/database/main.tf`
  - Features: Multi-AZ deployment, automated backups, encryption at rest (KMS), IAM authentication support
  - Connection details managed via Terraform variables and AWS Secrets Manager

**File Storage:**
- AWS S3 bucket (provisioned via Terraform)
  - Terraform config: `/Users/altairyedressov/School/finale/learning/terraform-infra/s3/s3.tf`
  - Purpose: Object storage for static assets and data

**Caching:**
- Not currently integrated (stateless applications)

## Authentication & Identity

**Auth Provider:**
- Custom - No external identity provider
- IAM authentication available for RDS database access via Terraform configuration (`iam_database_authentication_enabled`)
- AWS IAM roles for Kubernetes service accounts (IRSA) via Terraform

**AWS IAM:**
- Role provisioning automation via Terraform (`/Users/altairyedressov/School/finale/learning/terraform-infra/iam-role-module/`)
- Permission boundary policies for least-privilege access
- Service-to-service authentication via EKS pod identity

## Monitoring & Observability

**Error Tracking:**
- Health check endpoints on both services:
  - Frontend: `GET /health` on port 3000
  - Backend: `GET /api/health` on port 8000
- Kubernetes liveness/readiness probes configured in Helm templates

**Logs:**
- EFK Stack (Elasticsearch, Fluent Bit, Kibana) deployed via FluxCD
  - Kustomization: `/Users/altairyedressov/School/finale/learning/clusters/dev-projectx/efk-logging.yaml`
- Container logs streamed to ELK for centralized logging

**Monitoring Stack:**
- Prometheus + Grafana deployed via FluxCD
  - Kustomization: `/Users/altairyedressov/School/finale/learning/clusters/dev-projectx/monitoring.yaml`
- Thanos deployed for long-term metrics storage
  - Kustomization: `/Users/altairyedressov/School/finale/learning/clusters/dev-projectx/thanos.yaml`
- Alertmanager for alert routing and notifications

## CI/CD & Deployment

**Hosting:**
- AWS EKS (Elastic Kubernetes Service)
  - Cluster provisioned via Terraform: `/Users/altairyedressov/School/finale/learning/terraform-infra/eks-cluster/`
  - Multi-node setup with Karpenter-based autoscaling
  - Running on dev cluster in `dev-projectx` namespace

**CI Pipeline:**
- GitHub Actions - CI/CD orchestration
- Container images pushed to AWS ECR (Elastic Container Registry)
  - ECR configured via Terraform: `/Users/altairyedressov/School/finale/learning/terraform-infra/ecr/`

**GitOps:**
- FluxCD v1.8 - GitOps continuous deployment
  - Watches this GitHub repository for changes
  - Automatically reconciles cluster state with Git
  - Kustomization configurations: `/Users/altairyedressov/School/finale/learning/clusters/`
  - Sync interval: 10 minutes for most resources

**Service Mesh:**
- Istio - Traffic management and ingress routing
  - Deployment: `/Users/altairyedressov/School/finale/learning/clusters/dev-projectx/istio.yaml`
  - VirtualService routes traffic to portfolio services: `/Users/altairyedressov/School/finale/learning/portfolio/base/virtualservice.yaml`
  - Domain: yedressov.com (configured in VirtualService)

**Load Balancing:**
- AWS Load Balancer Controller deployed via FluxCD
  - Kustomization: `/Users/altairyedressov/School/finale/learning/clusters/dev-projectx/aws-lb-controller.yaml`
  - Manages AWS NLB/ALB for Kubernetes services

**Disaster Recovery:**
- Velero for Kubernetes cluster backups
  - Deployment: `/Users/altairyedressov/School/finale/learning/clusters/dev-projectx/velero.yaml`
- AWS RDS automated backups with retention policies

**Secrets Management:**
- Sealed Secrets for encrypted secrets in Git
  - Deployment: `/Users/altairyedressov/School/finale/learning/clusters/dev-projectx/sealed-secrets.yaml`
- AWS Secrets Manager for sensitive credentials

## Environment Configuration

**Required env vars (Frontend):**
- `PORT` - HTTP server port (default: 3000)
- `API_URL` - Backend API URL (default: http://localhost:8000)

**Required env vars (Backend):**
- None explicitly required (serves static data, no external API calls)

**Secrets location:**
- AWS Secrets Manager - Primary secret storage
- Sealed Secrets in Git - Kubernetes secrets encrypted at rest
- Environment variables injected via Kubernetes ConfigMaps and Secrets

## Webhooks & Callbacks

**Incoming:**
- GitHub webhooks trigger FluxCD reconciliation when Git repository updates
- Kubernetes Admission webhooks via Istio (mutual TLS validation)

**Outgoing:**
- FluxCD updates Kubernetes cluster state via Kubernetes API
- AWS SNS notifications for infrastructure alerts (configured in Terraform)
- Health check probes from Kubernetes to application endpoints

---

*Integration audit: 2026-03-28*
