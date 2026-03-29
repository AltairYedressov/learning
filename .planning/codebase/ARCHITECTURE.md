# Architecture

**Analysis Date:** 2026-03-28

## Pattern Overview

**Overall:** Multi-tier cloud-native application with GitOps infrastructure management

**Key Characteristics:**
- Two-tier portfolio application: Node.js Express frontend + Python FastAPI backend
- Kubernetes-native deployment on AWS EKS with Istio service mesh
- GitOps-driven infrastructure and application management via FluxCD
- Infrastructure as Code (IaC) using Terraform with modular workspace separation
- Automated CI/CD via GitHub Actions with OIDC-based AWS authentication
- Service mesh traffic routing with automatic mTLS between pods

## Layers

**Application Layer (Portfolio App):**
- Purpose: Render portfolio pages and serve resume data
- Location: `app/`
- Contains: Frontend (Node.js/Express), Backend (Python/FastAPI), Docker configurations
- Depends on: None (standalone application)
- Used by: End users via web browsers

**Kubernetes Deployment Layer:**
- Purpose: Orchestrate containerized services with health checks, networking, and resource management
- Location: `HelmCharts/portfolio/templates/`, `portfolio/base/`
- Contains: Helm chart templates for backend and frontend deployments, services, Istio VirtualService
- Depends on: Docker images from ECR, Istio control plane, Flux reconciliation
- Used by: EKS cluster, users accessing via Istio Gateway

**Service Mesh & Ingress Layer:**
- Purpose: Route external traffic to applications, handle TLS termination, enforce mTLS between services
- Location: `platform-tools/istio/`, `platform-tools/aws-lb-controller/`
- Contains: Istio Gateway (Envoy proxy), VirtualService routing rules, AWS Load Balancer Controller
- Depends on: EKS cluster, AWS NLB, Route53 DNS
- Used by: End users making HTTP/HTTPS requests, inter-pod communication

**Infrastructure Layer:**
- Purpose: Provision and manage AWS cloud resources (VPC, EKS, IAM, RDS, S3, DNS)
- Location: `terraform-infra/`
- Contains: Terraform modules and root workspaces for dev/prod environments
- Depends on: AWS account, GitHub token for Flux CD
- Used by: EKS cluster initialization, backend services (logging, backups, metrics)

**Platform Services Layer:**
- Purpose: Provide cluster-wide observability, backup, security, and autoscaling
- Location: `platform-tools/`
- Contains: Karpenter (node autoscaling), Velero (backup), EFK (logging), Thanos (metrics), Sealed Secrets (secret management)
- Depends on: EKS cluster, IAM roles (IRSA), S3 buckets, Prometheus
- Used by: All workloads in cluster, operators for debugging and recovery

**GitOps Orchestration Layer:**
- Purpose: Reconcile Git state with cluster state, manage application and platform deployments
- Location: `clusters/dev-projectx/`
- Contains: Flux CD Kustomization resources, HelmRelease manifests for all platform tools
- Depends on: GitHub repository, FluxCD (installed in cluster)
- Used by: Automatic reconciliation loop every 10m

## Data Flow

**User Request → Application Response:**

1. User requests `http://yedressov.com` in browser
2. Route53 (DNS) resolves to AWS Network Load Balancer (NLB) IP
3. NLB receives request on port 80, forwards to Istio Gateway (Envoy) on port 8080
4. Istio Gateway detects HTTP, issues 301 redirect to `https://yedressov.com`
5. User follows redirect, NLB receives HTTPS request on port 443
6. NLB terminates TLS using ACM certificate, forwards decrypted traffic to Istio Gateway port 8443
7. Istio Gateway (Envoy) matches against VirtualService routing rules:
   - If path starts with `/api` → routes to `portfolio-api` service (ClusterIP, port 8000)
   - Otherwise → routes to `portfolio-frontend` service (ClusterIP, port 3000)
8. Service discovery resolves service name to pod IP
9. Envoy sidecar (injected into pod) establishes mTLS connection to destination pod
10. Request reaches application container, response flows back through same path

**Container Build & Deployment:**

1. Developer pushes code to `main` branch
2. GitHub Actions workflow (`image.yaml`) triggers on `app/` changes
3. Workflow authenticates to AWS via OIDC (no long-lived credentials)
4. Docker images built and pushed to Amazon ECR with git commit SHA as tag
5. Helm chart pushed to ECR (OCI format) when `HelmCharts/` changes
6. Portfolio HelmRelease (`portfolio/base/helmrelease.yaml`) specifies image tag
7. FluxCD detects changes in Git repository every 1 minute
8. Flux reconciles HelmRelease → Helm chart pulled from ECR and rendered
9. Kubernetes applies new Deployments, triggers rolling update
10. New pods start with Istio sidecar injected (due to `istio-injection: enabled` label on namespace)

**Infrastructure Provisioning (Terraform):**

1. Developer pushes Terraform code to feature branch
2. GitHub Actions workflow (`deploy-workflow.yaml`) triggers on push
3. Terraform plan executed for each stack (iam-roles, networking, eks, etc.)
4. On merge to `main`, terraform apply executes (destructive operations only on main)
5. Terraform state stored in S3 backend with DynamoDB locking (prevents concurrent applies)
6. EKS cluster created with Flux CD pre-installed via IRSA-based access
7. Flux CD automatically deploys platform tools and applications based on Git state

**State Management:**

- **Application State:** Stateless frontends and backends (resume data hardcoded in backend)
- **Infrastructure State:** Managed by Terraform S3 backend (`372517046622-terraform-state-dev`)
- **Cluster State:** Reconciled by Flux CD every 10 minutes from Git repository
- **Secrets:** Stored in AWS Secrets Manager (RDS password), sealed via Sealed Secrets in cluster

## Key Abstractions

**HelmRelease (Flux):**
- Purpose: Declarative Helm chart deployment with GitOps reconciliation
- Examples: `portfolio/base/helmrelease.yaml`, `platform-tools/istio/istio-system/base/helmrelease.yaml`
- Pattern: Flux watches HelmRelease CRD, periodically runs `helm upgrade --install`, auto-rollback on failure

**VirtualService (Istio):**
- Purpose: Define application-level routing rules for traffic matching hostname and path
- Examples: `portfolio/base/virtualservice.yaml`
- Pattern: Matches on URI prefix (`/api` → backend, else → frontend), routes to K8s service names

**Gateway (Istio):**
- Purpose: Define which ports and protocols Envoy listens on, which hosts to accept
- Examples: `platform-tools/istio/istio-ingress/base/gateway.yaml`
- Pattern: Selector binds to Envoy deployment, dual ports for HTTP redirect (8080) and HTTPS (8443)

**Terraform Module:**
- Purpose: Reusable infrastructure building blocks (IAM roles, security groups, subnets)
- Examples: `terraform-infra/iam-role-module/`, `terraform-infra/networking/vpc-module/`
- Pattern: Module exposes variables and outputs, root workspace combines modules

**Kustomization (Flux):**
- Purpose: Git-based source of truth for which resources to deploy to cluster
- Examples: `clusters/dev-projectx/portfolio.yaml`, `clusters/dev-projectx/istio.yaml`
- Pattern: Points to kustomize base/overlay directory, Flux reconciles on interval

## Entry Points

**User Access:**
- Location: Browser → DNS (`yedressov.com`)
- Triggers: User typing URL
- Responsibilities: Route53 DNS resolution → AWS NLB → Istio Gateway → application

**Frontend Container:**
- Location: `app/frontend/src/server.js`
- Triggers: Kubernetes pod startup (from HelmRelease deployment)
- Responsibilities: Express server listens on port 3000, serves EJS templates, fetches data from backend API

**Backend Container:**
- Location: `app/backend/main.py`
- Triggers: Kubernetes pod startup (from HelmRelease deployment)
- Responsibilities: FastAPI server listens on port 8000, serves resume data as JSON endpoints

**Terraform Root Workspace:**
- Location: `terraform-infra/root/dev/{networking,iam-roles,eks,s3,database,ecr,dns}/`
- Triggers: GitHub Actions on push (plan only on feature branches, apply on main)
- Responsibilities: Create AWS infrastructure (VPC, EKS, IAM, RDS, S3, Route53)

**FluxCD Reconciliation:**
- Location: `clusters/dev-projectx/` (Kustomization manifests)
- Triggers: Every 10 minutes (or immediate when Git changes detected)
- Responsibilities: Clone Git repository, apply Kustomization, render HelmReleases, deploy to cluster

## Error Handling

**Strategy:** Graceful degradation with health checks and automatic rollback

**Patterns:**

- **Application-level errors:** Frontend catches backend unreachability, renders error page with fallback message (`error.ejs`)
- **Health checks:** Both frontend and backend expose `/health` endpoints; Kubernetes uses these for readiness/liveness probes
- **Container restart:** Kubelet automatically restarts failed containers based on restart policy
- **Deployment rollback:** Helm tracks previous releases; Flux auto-rollback on failed upgrade
- **Pod disruption budgets:** PDB ensures at least N pods remain during disruptions (platform tools)
- **IRSA token refresh:** EKS provides automatic token rotation for IAM role assumption

## Cross-Cutting Concerns

**Logging:** EFK stack (Elasticsearch, Filebeat, Kibana) deployed via `platform-tools/efk-logging/`
- All pod logs automatically collected from stdout
- Istio access logs sent to stdout (configurable in istiod values)
- Centralized search and visualization in Kibana

**Observability (Metrics):** Prometheus + Thanos + Grafana
- Prometheus scrapes metrics from Envoy, kubelet, application endpoints
- Thanos provides long-term storage (S3 backend in dev)
- Grafana dashboards visualize cluster and application health

**Authentication:** Kubernetes ServiceAccounts + IRSA (IAM Roles for Service Accounts)
- Platform tools (AWS LB Controller, Velero, etc.) use IRSA to assume AWS roles
- Flux CD uses GitHub PAT for repository access (passed as TF variable)
- Frontend and backend authenticate to each other via Istio mTLS (automatic)

**Authorization:** Kubernetes RBAC (via Flux and infrastructure layer)
- Service accounts have minimal required permissions (principle of least privilege)
- GitHub Actions authenticated via OIDC (no long-lived credentials stored)

**Traffic encryption:**
- **External (user → NLB):** TLS 1.2+ via ACM certificate on NLB
- **Service mesh (pod → pod):** Automatic mTLS via Istio (enabled by `enableAutoMtls: true`)
- **Backend database:** Unencrypted in dev (RDS password stored in Secrets Manager)

**Resource management:**
- Frontend/backend pods have CPU requests (100m) and limits (250m), memory requests (128Mi) and limits (256Mi)
- Platform tools resource limits configurable via Kustomize overlays (dev vs prod)

**Configuration:**
- Environment variables: `API_URL` passed to frontend deployment via HelmRelease values
- Secrets: RDS password stored in AWS Secrets Manager (not in Git)
- GitOps configuration: All app and platform tool deployments via HelmRelease CRD

---

*Architecture analysis: 2026-03-28*
