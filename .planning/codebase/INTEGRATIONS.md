# External Integrations

**Analysis Date:** 2026-04-15

## APIs & External Services

**AWS (sole cloud provider, region `us-east-1`, account `372517046622`):**
- **EKS** - Managed Kubernetes control plane (`terraform-infra/eks-cluster/eks.tf`)
  - Public endpoint enabled; nodes in public subnets (per project constraint)
  - Cluster log types: `api`, `audit`
- **EC2 / ASG** - Worker node group via launch template (`terraform-infra/eks-cluster/asg.tf`, `launch-tm.tf`)
- **VPC, IGW, route tables, subnets, security groups** (`terraform-infra/networking/*`)
- **RDS** - Managed relational DB (`terraform-infra/database/main.tf`)
  - Master password managed by AWS Secrets Manager (`manage_master_user_password = true`)
  - Optional cross-region DR replica + automated backup replication
- **S3** - Terraform state bucket `372517046622-terraform-state-dev` and Thanos object storage (`terraform-infra/s3/s3.tf`)
- **DynamoDB** - Terraform state lock table `372517046622-terraform-lock-dev`
- **ECR** - Docker image registry + OCI Helm chart registry (`terraform-infra/ecr/`, `HelmCharts/portfolio` published to `oci://372517046622.dkr.ecr.us-east-1.amazonaws.com/helm-charts`)
- **IAM + IRSA** - Cluster role, node role, EBS CSI IRSA, platform-tool service account roles (`terraform-infra/iam-role-module/`, `terraform-infra/eks-cluster/oidc-providers.tf`, `access-entries.tf`)
- **Route53** - DNS for `yedressov.com` (`terraform-infra/dns/route53`)
- **ACM** - TLS certificates for NLB / Istio ingress (`terraform-infra/dns/acm`)
- **NLB** - Provisioned by in-cluster AWS Load Balancer Controller for Istio ingress
- **Secrets Manager** - RDS master credential storage (auto-managed)
- **STS** - OIDC token exchange for GitHub Actions and IRSA

**SDK / clients used:**
- AWS provider in Terraform (`hashicorp/aws ~> 6.0`)
- `aws eks get-token` exec plugin for Kubernetes/Flux providers (`terraform-infra/eks-cluster/flux.tf`)
- `aws-actions/configure-aws-credentials@v4` and `aws-actions/amazon-ecr-login@v2` in GitHub Actions

**GitHub:**
- **GitHub API** via `integrations/github ~> 6.11` Terraform provider
  - Manages branch protection on `main` requiring status checks `publish-images` and `terraform (iam-roles)` (`terraform-infra/root/dev/eks/main.tf`)
- **GitHub Actions** - CI/CD platform (`.github/workflows/`)
- **GitHub OIDC** - Federated identity to AWS IAM role (`vars.IAM_ROLE`); no static AWS keys stored

**FluxCD <-> GitHub:**
- Flux bootstrapped from Terraform (`flux_bootstrap_git`) writing to `clusters/dev-projectx/`
- Authenticates to repo via PAT (`var.github_token` / `secrets.FLUX_GITHUB_PAT`) using basic auth (`username = "git"`)
- Pulls Helm charts from ECR OCI registry via `HelmRepository` with `provider: aws` (`portfolio/base/helmrepository.yaml`)
- Image automation polls ECR for new tags (`portfolio/image-automation/base/`)

**SMTP (Email Delivery):**
- Backend `/api/contact` sends mail via SMTP STARTTLS (`app/portfolio/api/app.py`)
- Default host `smtp.gmail.com:587`; recipient default `contact@yedressov.com`
- Credentials supplied through Sealed Secret synced into the `portfolio` namespace (see commit `cbf24b9`: "wire SealedSecret SMTP creds into backend")

## Data Storage

**Databases:**
- AWS RDS instance provisioned by `terraform-infra/database/main.tf`
  - Engine/version configurable via TF vars; storage encrypted with KMS key
  - Subnet group built from private subnets; SG sourced via `data.aws_security_group.database_sg`
  - IAM database authentication available (`iam_database_authentication_enabled`)
  - Note: Not currently consumed by the deployed portfolio app (frontend + Flask contact API are stateless)

**File / Object Storage:**
- AWS S3 buckets:
  - `372517046622-terraform-state-dev` - Terraform remote state (encrypted)
  - Thanos long-term metric blocks bucket (`platform-tools/thanos/`)
  - Velero backup bucket (`platform-tools/velero/`)

**Caching:**
- None (in-process rate-limiter dict only, `app/portfolio/api/app.py:_rate_store`)

## Authentication & Identity

**End-user auth:**
- None - public marketing/portfolio site, no login

**Service-to-service auth:**
- Istio mTLS between pods (PeerAuthentication / automatic mTLS in mesh)
- Kubernetes ServiceAccounts for platform tools

**Cloud auth:**
- IRSA (IAM Roles for Service Accounts) for in-cluster controllers (EBS CSI, AWS LB Controller, Karpenter, Velero, External DNS, Thanos)
- GitHub Actions assumes AWS role via OIDC (`id-token: write`)
- Terraform CLI inherits caller IAM identity via OIDC during CI

**Repo auth:**
- Flux uses GitHub PAT (`FLUX_GITHUB_PAT`) for repo read/write
- TF GitHub provider uses same PAT for branch-protection management

## Monitoring & Observability

**Metrics:**
- kube-prometheus-stack (`platform-tools/eks-monitoring/`)
- Thanos sidecar + store/query with S3 backend (`platform-tools/thanos/`)

**Logging:**
- EFK stack (Elasticsearch + Fluentd + Kibana) (`platform-tools/efk-logging/`)
- Application logs via stdout (`console.log`/`console.error` in Node, `logging` module in Python)
- EKS control-plane logs: `api`, `audit` shipped to CloudWatch (`terraform-infra/eks-cluster/eks.tf`)

**Error Tracking:**
- None integrated (no Sentry/Datadog/Rollbar SDKs detected)

## CI/CD & Deployment

**Hosting / runtime:**
- Application: AWS EKS in `us-east-1`
- Edge: AWS NLB -> Istio ingress gateway -> VirtualService -> portfolio Services
- DNS: Route53 `yedressov.com`; TLS via ACM on NLB

**CI Pipelines (`.github/workflows/`):**
- `deploy-workflow.yaml` - Terraform multi-stack deploy
  - Triggers: `push` to `feature/**` or `main`, `pull_request` to `main` (paths: `terraform-infra/**`)
  - Steps: setup-terraform 1.6.6 -> Checkov scan -> fmt -> validate -> plan -> apply (main only)
  - AWS auth via OIDC (`vars.IAM_ROLE`); state in S3 with DynamoDB lock
- `portfolio-images.yaml` - Build/push portfolio API + frontend Docker images
  - Triggers: changes under `app/portfolio/**`
  - Matrix builds `portfolio-api` and `portfolio-web` -> push to ECR tagged with `${{ github.sha }}`
  - Uses Buildx with GHA cache (`type=gha`)
- `helmchart.yaml` - Lint + publish portfolio Helm chart
  - Triggers: changes under `HelmCharts/portfolio/**`
  - `helm lint` + `helm template` smoke render -> `helm package` -> `helm push` to ECR OCI registry
- `validation-PT.yaml` - Ephemeral test cluster on `feature/PT**` branches
  - Creates throwaway EKS via `scripts/cluster-creation.sh`, bootstraps Flux, runs validation, then destroys

**GitOps (FluxCD reconcile loop, 10m interval):**
- Flux source of truth: `clusters/dev-projectx/` Kustomizations
- Manages: portfolio app, Istio, AWS LB Controller, Karpenter, EFK, monitoring, Thanos, Sealed Secrets, Kyverno, Velero, kube-system tweaks
- Image automation in `portfolio/image-automation/base/` updates HelmRelease image tags from ECR

**Branch protection (enforced via Terraform):**
- `main` requires checks: `publish-images`, `terraform (iam-roles)` (`terraform-infra/root/dev/eks/main.tf`)

## Environment Configuration

**Required GitHub Actions secrets / vars:**
- `secrets.FLUX_GITHUB_PAT` - GitHub PAT used by Flux + TF GitHub provider
- `vars.IAM_ROLE` - AWS IAM role ARN trusted by GitHub OIDC

**Terraform input variables (passed via `TF_VAR_*` in `deploy-workflow.yaml`):**
- `TF_VAR_github_token`, `TF_VAR_github_org`, `TF_VAR_github_repo`

**Application runtime env (set via Helm values / Sealed Secret):**
- Frontend: `BACKEND_URL`, `PORT`, `NODE_ENV`
- Backend: `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `RECIPIENT_EMAIL`, `ALLOWED_ORIGINS`, `RATE_LIMIT`, `RATE_WINDOW_MINUTES`, `MAX_BODY_BYTES`, `BACKEND_PORT`, `FLASK_DEBUG`

**Secret storage:**
- AWS Secrets Manager - RDS master password (auto-managed)
- Sealed Secrets controller in cluster - SMTP credentials and other workload secrets, encrypted in Git
- GitHub repo secrets - CI tokens (PAT only; no AWS static keys)
- `.env` files - local development only, not committed (not read by this analysis)

## Webhooks & Callbacks

**Incoming HTTP endpoints (exposed publicly via Istio ingress):**
- Frontend (`app/portfolio/frontend/server.js`):
  - `GET /health` - liveness probe (does NOT proxy to backend)
  - `GET /api/*` and `POST /api/*` - reverse-proxied to `BACKEND_URL` preserving `/api` prefix
  - `GET *` - SPA fallback to `public/index.html`
- Backend (`app/portfolio/api/app.py`):
  - `GET /health` and `GET /api/health` - liveness/readiness
  - `POST /api/contact` - validated contact form submission, rate-limited per `X-Forwarded-For`/`remote_addr`

**Outgoing calls:**
- Backend -> SMTP server (`SMTP_HOST:SMTP_PORT`, STARTTLS) for contact-form mail delivery
- Frontend -> Backend over in-cluster service DNS (`http://portfolio-api.portfolio.svc.cluster.local:8000`)
- Flux controllers -> GitHub HTTPS (repo polling) and ECR OCI (chart pulls)
- Image automation -> ECR (image tag listing)

**Webhooks:**
- None configured (Flux operates on poll interval rather than webhooks)

---

*Integration audit: 2026-04-15*
