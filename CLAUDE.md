<!-- GSD:project-start source:PROJECT.md -->
## Project

**ProjectX Infrastructure Security Audit**

A full security audit and hardening of the ProjectX AWS EKS platform — covering network/VPC, EKS & Kubernetes, IAM & access, and CI/CD & GitOps. The goal is production-ready infrastructure with all critical vulnerabilities identified and remediated collaboratively.

**Core Value:** Every layer of the infrastructure follows security best practices, with no critical or high-severity vulnerabilities remaining.

### Constraints

- **Architecture**: Nodes must remain in public subnets — user decision
- **Approach**: Collaborative fixing — each finding discussed before remediation
- **Tooling**: All changes via Terraform (infra) or GitOps manifests (platform/app) — no manual AWS console changes
- **Outcome**: Production-ready hardened infrastructure
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- JavaScript (Node.js 20) - Frontend server and application logic
- Python 3.12 - Backend API server and business logic
- HCL (Terraform) - Infrastructure as Code for AWS provisioning
- YAML - Kubernetes manifests, Helm charts, and FluxCD GitOps definitions
## Runtime
- Node.js 20 (Alpine Linux base for production containers)
- Python 3.12 (slim Linux base for production containers)
- Kubernetes (EKS on AWS) - Orchestration and deployment platform
- npm - JavaScript dependencies
- pip - Python dependencies
- Terraform (version ~6.0) - Infrastructure provisioning
## Frameworks
- Express 4.21.0 - Frontend web server and HTTP routing (`/Users/altairyedressov/School/finale/learning/app/frontend/src/server.js`)
- FastAPI 0.115.0 - Backend REST API and data endpoints (`/Users/altairyedressov/School/finale/learning/app/backend/main.py`)
- Uvicorn 0.30.0 - ASGI application server for FastAPI
- EJS 3.1.10 - Server-side template rendering for HTML views (`/Users/altairyedressov/School/finale/learning/app/frontend/views`)
- Helm v3 - Kubernetes package management (`/Users/altairyedressov/School/finale/learning/HelmCharts/portfolio`)
- FluxCD 1.8 - GitOps continuous deployment and cluster reconciliation (`/Users/altairyedressov/School/finale/learning/clusters`)
- Kustomize - Kubernetes manifest customization and overlays
- Istio - Service mesh for traffic management and ingress routing
- Docker - Containerization for both frontend and backend services
- Terraform 6.33.0 - Infrastructure provisioning on AWS
- GitHub Actions - CI/CD pipeline orchestration
## Key Dependencies
- axios 1.7.0 - HTTP client for frontend to call backend API (`/Users/altairyedressov/School/finale/learning/app/frontend/src/server.js`)
- pydantic 2.9.0 - Data validation and serialization for FastAPI models (`/Users/altairyedressov/School/finale/learning/app/backend/main.py`)
- AWS Provider (Terraform ~6.0) - Cloud infrastructure provisioning
- Flux Provider (Terraform ~1.8) - GitOps automation in Kubernetes
- GitHub Provider (Terraform ~6.11) - GitHub integration for Flux CD
- Kubernetes Provider (Terraform ~2.38) - Kubernetes cluster management
## Configuration
- Frontend configuration via environment variables:
- Backend configuration via FastAPI automatic documentation
- Infrastructure configuration via Terraform variables in `terraform-infra/` modules
- `Dockerfile` in `/Users/altairyedressov/School/finale/learning/app/frontend` - Builds Node.js 20 Alpine image
- `Dockerfile` in `/Users/altairyedressov/School/finale/learning/app/backend` - Builds Python 3.12 slim image
- Helm values defined in chart templates (`/Users/altairyedressov/School/finale/learning/HelmCharts/portfolio/Chart.yaml`)
## Platform Requirements
- Docker (for local containerization)
- Node.js 20 (for frontend development)
- Python 3.12 (for backend development)
- Terraform (for infrastructure changes)
- kubectl (for Kubernetes cluster interaction)
- Helm (for chart management)
- AWS EKS cluster (Kubernetes managed service on AWS)
- AWS RDS or Aurora database (provisioned via Terraform in `terraform-infra/database/`)
- AWS S3 for object storage (provisioned in `terraform-infra/s3/`)
- AWS ECR for container image registry
- AWS VPC with networking (defined in `terraform-infra/networking/`)
- Kubernetes nodes managed via Karpenter autoscaling
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- JavaScript/Node.js: camelCase or kebab-case (`server.js`, `package.json`)
- Python: lowercase_with_underscores (`main.py`, `requirements.txt`)
- Terraform: lowercase_with_underscores (`main.tf`, `variables.tf`, `outputs.tf`)
- YAML/Kubernetes: lowercase with hyphens (`portfolio.yaml`, `kustomization.yaml`)
- Shell scripts: lowercase with hyphens (`cluster-creation.sh`, `bootstrap-flux.sh`)
- camelCase for regular functions: `async (req, res)` arrow functions
- Route handlers use lowercase REST verb pattern: `app.get()`, `app.post()`
- Example: `axios.get()`, `express.static()`
- snake_case: `get_profile()`, `get_skills()`, `get_experience()`
- Class names: PascalCase (`BaseModel`, `FastAPI`, `HTTPException`)
- Example from `app/backend/main.py`: All endpoint handlers use snake_case
- JavaScript: camelCase (`const app = express()`, `const PORT = 3000`, `const API_URL`)
- Python: snake_case and UPPER_CASE for constants (`PROFILE`, `SKILLS`, `EXPERIENCE`, `CERTIFICATIONS`, `PROJECTS`)
- Terraform: UPPER_CASE for variables (`ACCOUNT_ID`), lowercase for resource references (`aws_s3_bucket.terraform_state`)
- Pydantic models use PascalCase: `class Profile(BaseModel)`, `class Skill(BaseModel)`, `class Experience(BaseModel)`
- Type hints with Python typing module: `List[str]`, `List[Skill]`, `Optional[str]`
- Example from `app/backend/main.py`: `class HealthCheck(BaseModel)`
- kebab-case for labels and names: `app: portfolio-api`, `tier: backend`
- snake_case for variable names: `aws_internet_gateway.igw`, `aws_s3_bucket.terraform_state`
## Code Style
- JavaScript: 2-space indentation (Express app uses standard Node.js patterns)
- Python: 4-space indentation (PEP 8 standard observed in `app/backend/main.py`)
- Terraform: 2-space indentation in block structures
- YAML/Kubernetes: 2-space indentation for all manifest files
- Not detected - No `.eslintrc`, `.pylintrc`, or linter configuration files found
- Code follows common conventions but no enforced linting rules
- Visual separators with ASCII art: `# ── Data Models ──────────────────────────────────────────────────────────────`
- Used consistently in `app/backend/main.py` to section logical code blocks
- Used in `app/frontend/src/server.js` with `// ── Main route ──────────────────────────────────────────────────────────────`
- Short inline comments for clarification, avoiding over-commenting
## Documentation
- Python: Module docstrings at the top describe purpose
- JavaScript: Block comments at top describe module purpose
- Python: Minimal - simple endpoint handlers rely on function names and type hints
- Python type hints used throughout: `response_model=Profile`, `response_model=List[Skill]`
- JavaScript: JSDoc-style comments absent; function clarity through naming and middleware
## Import Organization
- Type imports separated: `from typing import List, Optional`
- Not detected - No TypeScript path aliases configured
- All imports use relative/standard library paths
## Error Handling
- Try-catch blocks with async handlers
- Pattern: Catch block logs error with `console.error()` and returns HTTP status with fallback response
- Example from `app/frontend/src/server.js` line 19-28:
- Silent catch (no error message) for non-critical failures: Line 40 `catch { }` for degraded state
- HTTP status codes: 503 for service unavailable
- HTTPException raised for errors: `from fastapi import HTTPException`
- Not extensively used in current code (simple endpoints return data directly)
- Pydantic validation built-in: Invalid data rejected by BaseModel validation
## Environment Configuration
- JavaScript: Read with `process.env.PORT`, `process.env.API_URL` with fallback defaults
- Python: Not actively used in current code; could use `os.getenv()`
- Framework: `console.log()` and `console.error()` (JavaScript), `print()` (Python, not extensively used)
- Pattern in JavaScript: Information-level logs with emoji prefix (`✦`)
- Error logs: `console.error("Backend API unreachable:", err.message)`
- No structured logging framework detected
## Function Design
- JavaScript: Express middleware pattern with `(req, res)` or `(req, res, next)`
- Python: FastAPI handlers take no request parameters directly; use `response_model` for type validation
- JavaScript: `res.render()` for template rendering, `res.json()` for JSON, `res.status()` for HTTP responses
- Python: Return native Python objects, Pydantic models serialized automatically to JSON
## Module Design
- JavaScript: Single app instance used throughout: `app.get()`, `app.listen()`
- Python: Single FastAPI app instance: `@app.get()`, `@app.post()`
- No barrel files or aggregated exports in analyzed code
- JavaScript: Single file (`server.js`) - monolithic but simple for small service
- Python: Single file (`main.py`) - monolithic structure with clear section separation via ASCII comments
- Terraform: Multiple files per concern (main.tf, variables.tf, outputs.tf, data-blocks.tf) - modular pattern
- Kubernetes: Multiple manifests per concern (01-backend.yaml, 02-frontend.yaml) - clear ordering via numbers
## Data Models
- All data models extend `BaseModel`
- Type hints required on all fields
- Optional fields marked with `Optional[FieldType]` or default values
- Example: `class Profile(BaseModel):` with typed fields
- Consistent use of `List[T]` for collections
- `.dict()` method used to convert models to dictionaries for JSON serialization
- No type system (plain JavaScript); relies on runtime behavior
- Object destructuring used: `const { data } = await axios.get()`
## Configuration Files
- Terraform configuration split across logical files: `main.tf`, `variables.tf`, `outputs.tf`, `data-blocks.tf`
- Variables documented with `description` field
- Resources tagged with `Environment` and `Name` labels
- Consistent use of interpolation: `"${var.ACCOUNT_ID}-terraform-state-dev"`
- YAML manifests follow standard Kubernetes API conventions
- Metadata includes `name`, `namespace`, `labels` with consistent app labels
- Resources templated with Helm: `{{ .Values.namespace.name }}`
- Comments use visual separators: `# ── Section Name ────────────────────`
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Two-tier portfolio application: Node.js Express frontend + Python FastAPI backend
- Kubernetes-native deployment on AWS EKS with Istio service mesh
- GitOps-driven infrastructure and application management via FluxCD
- Infrastructure as Code (IaC) using Terraform with modular workspace separation
- Automated CI/CD via GitHub Actions with OIDC-based AWS authentication
- Service mesh traffic routing with automatic mTLS between pods
## Layers
- Purpose: Render portfolio pages and serve resume data
- Location: `app/`
- Contains: Frontend (Node.js/Express), Backend (Python/FastAPI), Docker configurations
- Depends on: None (standalone application)
- Used by: End users via web browsers
- Purpose: Orchestrate containerized services with health checks, networking, and resource management
- Location: `HelmCharts/portfolio/templates/`, `portfolio/base/`
- Contains: Helm chart templates for backend and frontend deployments, services, Istio VirtualService
- Depends on: Docker images from ECR, Istio control plane, Flux reconciliation
- Used by: EKS cluster, users accessing via Istio Gateway
- Purpose: Route external traffic to applications, handle TLS termination, enforce mTLS between services
- Location: `platform-tools/istio/`, `platform-tools/aws-lb-controller/`
- Contains: Istio Gateway (Envoy proxy), VirtualService routing rules, AWS Load Balancer Controller
- Depends on: EKS cluster, AWS NLB, Route53 DNS
- Used by: End users making HTTP/HTTPS requests, inter-pod communication
- Purpose: Provision and manage AWS cloud resources (VPC, EKS, IAM, RDS, S3, DNS)
- Location: `terraform-infra/`
- Contains: Terraform modules and root workspaces for dev/prod environments
- Depends on: AWS account, GitHub token for Flux CD
- Used by: EKS cluster initialization, backend services (logging, backups, metrics)
- Purpose: Provide cluster-wide observability, backup, security, and autoscaling
- Location: `platform-tools/`
- Contains: Karpenter (node autoscaling), Velero (backup), EFK (logging), Thanos (metrics), Sealed Secrets (secret management)
- Depends on: EKS cluster, IAM roles (IRSA), S3 buckets, Prometheus
- Used by: All workloads in cluster, operators for debugging and recovery
- Purpose: Reconcile Git state with cluster state, manage application and platform deployments
- Location: `clusters/dev-projectx/`
- Contains: Flux CD Kustomization resources, HelmRelease manifests for all platform tools
- Depends on: GitHub repository, FluxCD (installed in cluster)
- Used by: Automatic reconciliation loop every 10m
## Data Flow
- **Application State:** Stateless frontends and backends (resume data hardcoded in backend)
- **Infrastructure State:** Managed by Terraform S3 backend (`372517046622-terraform-state-dev`)
- **Cluster State:** Reconciled by Flux CD every 10 minutes from Git repository
- **Secrets:** Stored in AWS Secrets Manager (RDS password), sealed via Sealed Secrets in cluster
## Key Abstractions
- Purpose: Declarative Helm chart deployment with GitOps reconciliation
- Examples: `portfolio/base/helmrelease.yaml`, `platform-tools/istio/istio-system/base/helmrelease.yaml`
- Pattern: Flux watches HelmRelease CRD, periodically runs `helm upgrade --install`, auto-rollback on failure
- Purpose: Define application-level routing rules for traffic matching hostname and path
- Examples: `portfolio/base/virtualservice.yaml`
- Pattern: Matches on URI prefix (`/api` → backend, else → frontend), routes to K8s service names
- Purpose: Define which ports and protocols Envoy listens on, which hosts to accept
- Examples: `platform-tools/istio/istio-ingress/base/gateway.yaml`
- Pattern: Selector binds to Envoy deployment, dual ports for HTTP redirect (8080) and HTTPS (8443)
- Purpose: Reusable infrastructure building blocks (IAM roles, security groups, subnets)
- Examples: `terraform-infra/iam-role-module/`, `terraform-infra/networking/vpc-module/`
- Pattern: Module exposes variables and outputs, root workspace combines modules
- Purpose: Git-based source of truth for which resources to deploy to cluster
- Examples: `clusters/dev-projectx/portfolio.yaml`, `clusters/dev-projectx/istio.yaml`
- Pattern: Points to kustomize base/overlay directory, Flux reconciles on interval
## Entry Points
- Location: Browser → DNS (`yedressov.com`)
- Triggers: User typing URL
- Responsibilities: Route53 DNS resolution → AWS NLB → Istio Gateway → application
- Location: `app/frontend/src/server.js`
- Triggers: Kubernetes pod startup (from HelmRelease deployment)
- Responsibilities: Express server listens on port 3000, serves EJS templates, fetches data from backend API
- Location: `app/backend/main.py`
- Triggers: Kubernetes pod startup (from HelmRelease deployment)
- Responsibilities: FastAPI server listens on port 8000, serves resume data as JSON endpoints
- Location: `terraform-infra/root/dev/{networking,iam-roles,eks,s3,database,ecr,dns}/`
- Triggers: GitHub Actions on push (plan only on feature branches, apply on main)
- Responsibilities: Create AWS infrastructure (VPC, EKS, IAM, RDS, S3, Route53)
- Location: `clusters/dev-projectx/` (Kustomization manifests)
- Triggers: Every 10 minutes (or immediate when Git changes detected)
- Responsibilities: Clone Git repository, apply Kustomization, render HelmReleases, deploy to cluster
## Error Handling
- **Application-level errors:** Frontend catches backend unreachability, renders error page with fallback message (`error.ejs`)
- **Health checks:** Both frontend and backend expose `/health` endpoints; Kubernetes uses these for readiness/liveness probes
- **Container restart:** Kubelet automatically restarts failed containers based on restart policy
- **Deployment rollback:** Helm tracks previous releases; Flux auto-rollback on failed upgrade
- **Pod disruption budgets:** PDB ensures at least N pods remain during disruptions (platform tools)
- **IRSA token refresh:** EKS provides automatic token rotation for IAM role assumption
## Cross-Cutting Concerns
- All pod logs automatically collected from stdout
- Istio access logs sent to stdout (configurable in istiod values)
- Centralized search and visualization in Kibana
- Prometheus scrapes metrics from Envoy, kubelet, application endpoints
- Thanos provides long-term storage (S3 backend in dev)
- Grafana dashboards visualize cluster and application health
- Platform tools (AWS LB Controller, Velero, etc.) use IRSA to assume AWS roles
- Flux CD uses GitHub PAT for repository access (passed as TF variable)
- Frontend and backend authenticate to each other via Istio mTLS (automatic)
- Service accounts have minimal required permissions (principle of least privilege)
- GitHub Actions authenticated via OIDC (no long-lived credentials stored)
- **External (user → NLB):** TLS 1.2+ via ACM certificate on NLB
- **Service mesh (pod → pod):** Automatic mTLS via Istio (enabled by `enableAutoMtls: true`)
- **Backend database:** Unencrypted in dev (RDS password stored in Secrets Manager)
- Frontend/backend pods have CPU requests (100m) and limits (250m), memory requests (128Mi) and limits (256Mi)
- Platform tools resource limits configurable via Kustomize overlays (dev vs prod)
- Environment variables: `API_URL` passed to frontend deployment via HelmRelease values
- Secrets: RDS password stored in AWS Secrets Manager (not in Git)
- GitOps configuration: All app and platform tool deployments via HelmRelease CRD
<!-- GSD:architecture-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
