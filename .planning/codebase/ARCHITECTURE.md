# Architecture

**Analysis Date:** 2026-04-15

## Pattern Overview

**Overall:** Two-tier cloud-native portfolio application deployed on AWS EKS with Istio service mesh and GitOps reconciliation.

**Key Characteristics:**
- Stateless frontend and backend microservices running in Kubernetes
- Infrastructure as Code (Terraform) with modular workspace separation (dev/prod)
- Git-driven cluster state via FluxCD (10-minute reconciliation interval)
- Service mesh traffic management with automatic mTLS between pods
- Automated CI/CD via GitHub Actions with OIDC-based AWS authentication
- Complete observability stack: EFK logging, Prometheus/Grafana metrics, Thanos long-term storage, Velero backup

## Layers

**Application Layer:**
- Purpose: Serve portfolio pages and resume data to end users
- Location: `app/frontend/` (Node.js/Express), `app/backend/` (Python/FastAPI)
- Contains: Express web server, EJS templates, FastAPI REST endpoints, Pydantic data models
- Depends on: Docker containers, Kubernetes pod infrastructure, Istio traffic routing
- Used by: End users via browser, frontend service calls backend API internally

**Kubernetes/Container Layer:**
- Purpose: Orchestrate containerized services with health checks, networking, resource management, and auto-scaling
- Location: `HelmCharts/portfolio/templates/`, `portfolio/base/` (base manifests), `portfolio/overlays/dev/` (environment-specific patches)
- Contains: Helm chart templates for backend/frontend Deployments, ClusterIP Services, Istio VirtualService, NetworkPolicy, namespace isolation
- Depends on: EKS cluster, Docker images from ECR, Flux reconciliation, Istio control plane
- Used by: EKS cluster for pod scheduling, Flux for GitOps reconciliation

**Service Mesh & Ingress Layer:**
- Purpose: Route external traffic to applications, enforce mTLS between pods, handle TLS termination
- Location: `platform-tools/istio/` (Istio Gateway/VirtualService templates), `platform-tools/aws-lb-controller/` (NLB integration)
- Contains: Istio Gateway (Envoy proxy on public IPs), VirtualService routing rules (hostname/path-based), AWS Load Balancer Controller for NLB provisioning
- Depends on: EKS cluster, AWS NLB, Route53 DNS, Envoy sidecar proxies
- Used by: End users making HTTP/HTTPS requests, inter-pod service-to-service communication

**Infrastructure & Platform Tools Layer:**
- Purpose: Provision and manage cloud resources, provide observability and operational tools
- Location: `terraform-infra/` (AWS resource provisioning), `platform-tools/` (Kubernetes cluster-wide tools)
- Contains: 
  - Terraform: VPC/networking, EKS cluster, IAM roles, RDS database, S3 state/backups, ECR registry, Route53/ACM DNS
  - Platform tools: Karpenter (node autoscaling), Velero (backup), EFK (logging), Prometheus/Grafana/Thanos (metrics), Sealed Secrets (secret encryption), Kyverno (policy enforcement)
- Depends on: AWS account, GitHub token for Flux CD, IAM permissions
- Used by: All workloads in cluster, operators for debugging and recovery

**GitOps Orchestration Layer:**
- Purpose: Provide Git as single source of truth for cluster and application state
- Location: `clusters/dev-projectx/` (Flux Kustomization manifests), `portfolio/base/helmrelease.yaml` (HelmRelease CRD)
- Contains: Flux CD Kustomization resources pointing to Git paths, HelmRelease manifests for all deployments (apps + platform tools), sealed secrets for sensitive config
- Depends on: GitHub repository, FluxCD Operator (installed in cluster), Helm repositories
- Used by: Flux reconciliation loop (every 10m) to pull Git state and apply to cluster

## Data Flow

**User Request → Application:**

1. User types `yedressov.com` → Route53 resolves to AWS NLB public IP
2. NLB terminates TLS 1.2+ via ACM certificate → forwards to Istio Gateway (Envoy proxy)
3. Istio Gateway matches hostname `yedressov.com` against VirtualService rules (from `portfolio/base/virtualservice.yaml`)
4. Request path-based routing: `/api/*` → portfolio-api (backend), else → portfolio-frontend (frontend)
5. Envoy routes to Kubernetes Service (ClusterIP) → Pod with matching labels
6. Pod health checks verify readiness before receiving traffic (HTTP GET `/health` endpoint)

**Frontend → Backend Communication:**

1. Browser loads frontend pod (Express server on port 3000)
2. Frontend async handler (from `app/frontend/src/server.js` line 19-29) calls `axios.get('http://portfolio-api.portfolio.svc.cluster.local:8000/api/all')`
3. Service mesh intercepts: Envoy sidecar on frontend pod intercepts request
4. Automatic mTLS established between frontend and backend Envoy sidecars
5. Backend FastAPI handler returns JSON (`/api/all` from `app/backend/main.py` line 213-222)
6. Frontend renders EJS template with resume data

**Infrastructure State Management:**

1. Developer pushes code to GitHub main branch
2. GitHub Actions workflow (`.github/workflows/image.yaml`) runs CI/CD:
   - Docker builds frontend and backend images
   - Trivy scans for vulnerabilities
   - Images pushed to ECR with short SHA tag (e.g., `5e83c60`)
3. Terraform applies infrastructure changes (root workspace orchestrates: networking, EKS, IAM, database, ECR, DNS)
4. FluxCD reconciliation detects Git changes every 10 minutes
5. Flux reads HelmRelease CRD (from `portfolio/base/helmrelease.yaml`) → pulls Helm chart from ECR repository
6. Helm renders chart templates with values → kubectl applies manifests
7. Karpenter autoscaler provisions/terminates nodes based on pod resource requests
8. Pods scheduled by Kubelet → readiness probes check health → service receives traffic

**Secrets & Configuration:**

- Environment variables (e.g., `API_URL`) passed to frontend via HelmRelease values (from `portfolio/base/helmrelease.yaml` line 32)
- Database credentials (RDS password) stored in AWS Secrets Manager (not in Git)
- Sealed Secrets encrypts sensitive cluster config before Git commit (managed by sealed-secrets platform tool)

## Key Abstractions

**HelmRelease CRD (Flux + Helm Integration):**
- Purpose: Declarative Helm chart deployment with GitOps reconciliation and auto-rollback
- Examples: `portfolio/base/helmrelease.yaml`, `platform-tools/eks-monitoring/base/helmrelease.yaml`
- Pattern: Flux watches HelmRelease resource, periodically runs `helm upgrade --install`, auto-rolls back on failed upgrade, reconciliation interval configurable (10m default)
- Implementation: Helm chart (`HelmCharts/portfolio/Chart.yaml`) defines templates, HelmRelease specifies which chart version to deploy and custom values

**Istio VirtualService (Layer 7 Routing):**
- Purpose: Define application-level routing rules for traffic matching hostname and URI path
- Examples: `portfolio/base/virtualservice.yaml`
- Pattern: Matches on `hosts` (DNS) and `http[].match.uri.prefix` (path prefix) → routes to Kubernetes Service names with specific ports
- Use case: `/api` → `portfolio-api:8000`, else → `portfolio-frontend:3000`

**Istio Gateway (Layer 4/7 Entry Point):**
- Purpose: Define which ports/protocols Envoy listens on and which hosts to accept
- Examples: `platform-tools/istio/istio-ingress/base/gateway.yaml`
- Pattern: Selector `istio: ingressgateway` binds to Envoy Deployment, dual ports (8080 HTTP redirect, 8443 HTTPS), certificate reference
- Integration: AWS NLB → Istio Gateway → VirtualService routing

**Terraform Module Pattern (Reusable Infrastructure):**
- Purpose: Package infrastructure building blocks (networking, IAM, EKS, databases) for reuse across dev/prod
- Examples: `terraform-infra/iam-role-module/main.tf`, `terraform-infra/eks-cluster/`, `terraform-infra/networking/vpc-module/`
- Pattern: Module exposes `variables.tf` for inputs, `main.tf` for resources, `outputs.tf` for return values; root workspace (`terraform-infra/root/dev/`) instantiates modules with environment-specific vars
- Use case: Create consistent IAM roles, VPCs, EKS clusters across multiple regions/accounts without code duplication

**Kustomization Resource (Flux + Git Paths):**
- Purpose: Git-based source of truth for which resources to deploy to cluster
- Examples: `clusters/dev-projectx/portfolio.yaml`, `clusters/dev-projectx/istio.yaml`, `clusters/dev-projectx/karpenter.yaml`
- Pattern: Points to kustomize base/overlay directory in Git (e.g., `./portfolio/base`), Flux reconciles on interval and applies manifests
- Workflow: Change Git → Flux detects → kustomize builds → kubectl apply → cluster converges to Git state

**Security Groups & Network Policies:**
- Purpose: Network isolation at cloud (AWS) and Kubernetes layers
- Examples: `terraform-infra/networking/security-group/` (AWS), `portfolio/base/networkpolicy.yaml` (Kubernetes), `platform-tools/eks-monitoring/base/networkpolicy.yaml` (platform tools)
- Pattern: AWS security groups control EC2 node-to-node and external traffic; Kubernetes NetworkPolicy enforces pod-to-pod communication rules (namespace boundaries, label selectors)

**Service Accounts & IRSA (IAM Roles for Service Accounts):**
- Purpose: Provide least-privilege AWS IAM permissions to Kubernetes pods
- Pattern: Kubernetes ServiceAccount linked to IAM role via OIDC provider; Pod assumes role via webhook mutation
- Use case: Karpenter controller, Velero backup, Flux CD, AWS Load Balancer Controller each have dedicated ServiceAccount + IAM role with only required permissions

## Entry Points

**User Browser → Public Internet:**
- Location: Route53 → AWS NLB → Istio Gateway public IP (0.0.0.0:8443)
- Triggers: User navigates to `yedressov.com`
- Responsibilities: DNS resolution, TLS termination, initial Envoy routing to VirtualService rules

**Frontend Web Server:**
- Location: `app/frontend/src/server.js`
- Triggers: Kubernetes pod startup (initiated by HelmRelease from `portfolio/base/helmrelease.yaml`)
- Responsibilities: Listen on port 3000, serve EJS templates for portfolio pages, call backend API, respond to /health liveness/readiness probes

**Backend API Server:**
- Location: `app/backend/main.py`
- Triggers: Kubernetes pod startup (initiated by HelmRelease)
- Responsibilities: Listen on port 8000, serve resume data as JSON endpoints (/api/profile, /api/skills, /api/experience, /api/all), respond to /health probes, enforce rate limiting (60/min), validate request body size (1KB max)

**Terraform Root Workspace:**
- Location: `terraform-infra/root/dev/` (subdirectories: networking, iam-roles, eks, s3, database, ecr, dns)
- Triggers: GitHub Actions on main branch push (plan on feature branches, apply on main)
- Responsibilities: Orchestrate module calls, manage AWS infrastructure state in S3 backend, enforce branch protection CI/CD gates

**FluxCD Reconciliation Loop:**
- Location: `clusters/dev-projectx/` (Kustomization manifests)
- Triggers: Every 10 minutes (or immediate when Git changes detected)
- Responsibilities: Clone GitHub repository, apply Kustomization overlays, render HelmReleases, deploy to EKS cluster, auto-rollback on failed upgrade

**GitHub Actions CI/CD Pipeline:**
- Location: `.github/workflows/image.yaml` (Docker image build/push), `.github/workflows/deploy-workflow.yaml` (Terraform apply)
- Triggers: Push to main branch, pull requests
- Responsibilities: Build/scan Docker images, push to ECR, run Terraform plan/apply, trigger Flux reconciliation

## Error Handling

**Application-Level Errors:**
- Frontend catches backend unreachability, renders error page with fallback message (response status 503, from `app/frontend/src/server.js` line 23-27)
- Pattern: `try-catch` with axios; silent catch on non-critical health checks (line 40: `catch { }`)
- Backend returns HTTPException for validation errors, rate-limit errors, request body too large (413 status)

**Container Restart:**
- Kubernetes liveness probe (HTTP GET `/api/health`) restarts failed container after initialDelaySeconds + periodSeconds
- Readiness probe ensures traffic only routes to healthy pods
- Restart policy: `Always` (default) - kubelet restarts pod on crash

**Deployment Rollback:**
- Helm tracks previous releases; HelmRelease auto-rollback on failed upgrade (Flux feature)
- Git history provides full audit trail; revert commit → Flux reconciles to previous state

**Pod Disruption Budgets (PDB):**
- Platform tools (Prometheus, Grafana, EFK) use PDB to ensure minimum replicas during voluntary disruptions (node drains, cluster upgrades)

**IRSA Token Refresh:**
- EKS automatically refreshes IRSA tokens every 1 hour (default), seamless to pods; no manual credential rotation needed

## Cross-Cutting Concerns

**Logging:**
- All pod stdout automatically collected via container runtime → Fluent Bit → Elasticsearch
- Istio access logs sent to stdout (configurable in istiod HelmRelease values)
- Centralized search and visualization in Kibana (platform-tools/efk-logging)

**Monitoring & Alerting:**
- Prometheus scrapes metrics from Envoy sidecars, kubelet, application endpoints (/metrics)
- Grafana dashboards visualize cluster and application health metrics
- Alertmanager sends alerts to configured channels (email, Slack, etc.)
- Thanos provides long-term metric storage (S3 backend in dev, configurable in platform-tools/thanos)

**Authorization & Authentication:**
- Platform tools (Karpenter, Velero, AWS LB Controller, Flux CD) use IRSA to assume AWS roles
- Frontend-to-backend communication: Istio mTLS automatic (mutual TLS between Envoy sidecars)
- User → external: TLS 1.2+ via NLB + ACM certificate
- GitHub Actions uses OIDC token exchange (no long-lived credentials stored in GitHub secrets)

**Network Security:**
- External (user → NLB): TLS 1.2+ via ACM certificate on NLB
- Service mesh (pod → pod): Automatic mTLS via Istio (enableAutoMtls: true in istiod config)
- Node-to-node: AWS security groups restrict traffic to Kubernetes API, kubelet, CNI
- Pod-to-pod: Kubernetes NetworkPolicy enforces communication rules within namespaces (deny-all default, explicit allow rules)

**Resource Management:**
- Frontend/backend pods: CPU requests 100m, limits 250m; memory requests 128Mi, limits 256Mi
- Platform tools resource limits configurable via Kustomize overlays (dev vs prod)
- Karpenter autoscaler provisions nodes based on pending pod requests, terminates idle nodes

**Configuration Management:**
- Environment variables: `API_URL` passed to frontend deployment via HelmRelease values (`portfolio/base/helmrelease.yaml` line 32)
- Secrets: RDS password stored in AWS Secrets Manager, referenced by Terraform
- GitOps configuration: All app and platform tool deployments via HelmRelease CRD (Git as SSOT)
- Sealed Secrets: Sensitive cluster config encrypted before Git commit, decrypted by cluster sealed-secrets controller
