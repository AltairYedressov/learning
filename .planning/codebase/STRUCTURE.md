# Codebase Structure

**Analysis Date:** 2026-04-15

## Directory Layout

```
learning/
├── app/                          # Application source (containerized workloads)
│   ├── README.md
│   └── portfolio/
│       ├── frontend/             # Node 20 / Express SPA server + proxy
│       │   ├── server.js
│       │   ├── package.json
│       │   ├── Dockerfile
│       │   ├── .dockerignore
│       │   ├── .env.example
│       │   └── public/{index.html,css/style.css,js/main.js}
│       └── api/                  # Python 3.12 / Flask contact-form API
│           ├── app.py
│           ├── requirements.txt
│           ├── Dockerfile
│           ├── .dockerignore
│           └── .env.example
│
├── HelmCharts/                   # Helm charts published to ECR OCI registry
│   └── portfolio/
│       ├── Chart.yaml            # version 0.3.0, appVersion 0.0.1
│       ├── values.yaml           # Default values (overridden by HelmRelease)
│       └── templates/
│           ├── 01-backend.yaml   # api Deployment + ClusterIP Service
│           ├── 02-frontend.yaml  # frontend Deployment + ClusterIP Service
│           └── sealed-secret.yaml# portfolio-smtp SealedSecret
│
├── portfolio/                    # GitOps binding for the portfolio app
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── helmrepository.yaml   # OCI HelmRepository → ECR
│   │   ├── helmrelease.yaml      # HelmRelease pinning chart 0.3.0 + values
│   │   ├── virtualservice.yaml   # Istio routing (/api → api, else → frontend)
│   │   ├── kustomization.yaml
│   │   └── README.md
│   ├── overlays/{dev,prod}/      # Env-specific patches (only dev populated)
│   └── image-automation/base/    # Flux image-update-automation scaffolding
│       ├── image-repository-{web,api}.yaml
│       ├── image-policy-{web,api}.yaml
│       ├── image-update-automation.yaml
│       └── kustomization.yaml
│
├── platform-tools/               # Cluster-wide capabilities (Kustomize bases + overlays)
│   ├── istio/
│   │   ├── istio-system/{base,overlays/{dev,prod}}/      # Control plane
│   │   └── istio-ingress/{base,overlays/{dev,prod}}/     # Gateway + Envoy data plane
│   ├── karpenter/
│   │   ├── {base,overlays/{dev,prod}}/                   # Karpenter controller
│   │   └── nodepool/{base,overlays/{dev,prod}}/          # NodePool CRDs (split Kustomization)
│   ├── aws-lb-controller/{base,overlays/{dev,prod}}/     # AWS Load Balancer Controller
│   ├── sealed-secrets/{base,overlays/{dev,prod}}/        # bitnami-labs sealed-secrets
│   ├── velero/{base,overlays/{dev,prod}}/                # Backup → S3
│   ├── efk-logging/{base,overlays/{dev,prod}}/           # Elasticsearch + Fluent + Kibana
│   ├── thanos/{base,overlays/{dev,prod}}/                # Long-term metrics storage
│   ├── eks-monitoring/{base,overlays/{dev,prod}}/        # Prometheus stack
│   ├── kyverno/{base,overlays/dev}/                      # Policy engine (no prod overlay yet)
│   └── kube-system/base/                                 # kube-system namespace bits
│
├── clusters/                     # Per-cluster Flux Kustomizations (entry into the cluster)
│   ├── dev-projectx/             # Live cluster
│   │   ├── flux-system/
│   │   │   ├── gotk-components.yaml      # Flux controllers
│   │   │   ├── gotk-sync.yaml            # GitRepository + root Kustomization
│   │   │   ├── kustomization.yaml
│   │   │   ├── networkpolicy.yaml
│   │   │   └── image-automation-sa.yaml
│   │   ├── portfolio.yaml        # Reconciles ./portfolio/base
│   │   ├── istio.yaml            # istio-system + istio-ingress (with dependsOn)
│   │   ├── karpenter.yaml        # karpenter + karpenter-nodepool
│   │   ├── aws-lb-controller.yaml
│   │   ├── sealed-secrets.yaml
│   │   ├── velero.yaml
│   │   ├── efk-logging.yaml
│   │   ├── thanos.yaml
│   │   ├── kyverno.yaml
│   │   ├── monitoring.yaml
│   │   └── kube-system.yaml
│   └── test/flux-system/         # Scaffold-only test cluster
│
├── terraform-infra/              # Infrastructure as Code (modules + per-env root workspaces)
│   ├── bootstrap/                # Initial S3 backend bucket + DynamoDB lock
│   │   ├── main.tf, providers.tf, variables.tf
│   ├── networking/               # VPC primitives (modules)
│   │   ├── vpc-module/           # aws_vpc
│   │   ├── subnets/              # public subnets (nodes live here per constraint)
│   │   ├── igw/                  # internet gateway
│   │   ├── route-tables/
│   │   └── security-group/
│   ├── eks-cluster/              # EKS module (consumed by root/{dev,prod}/eks)
│   │   ├── eks.tf                # aws_eks_cluster
│   │   ├── asg.tf, launch-tm.tf  # Worker node ASG + launch template
│   │   ├── addons.tf             # EKS managed addons
│   │   ├── access-entries.tf     # Access Entry API (post-aws-auth)
│   │   ├── oidc-providers.tf     # IRSA OIDC provider
│   │   ├── flux.tf               # Flux bootstrap (Flux + GitHub providers)
│   │   ├── data-blocks.tf, variables.tf, outputs.tf, README.md
│   ├── iam-role-module/          # Reusable IAM role + policy attachments
│   │   ├── main.tf, variables.tf
│   │   └── Policies/             # JSON policy documents
│   │       ├── aws_lb_controller_policy.json
│   │       ├── eks_worker_node_policy.json
│   │       ├── github_actions_ecr_push_policy.json
│   │       ├── image_reflector_ecr_read_policy.json
│   │       ├── karpenter_policy.json
│   │       ├── thanos_policy.json
│   │       └── velero_policy.json
│   ├── ecr/                      # ECR repositories module
│   ├── s3/                       # S3 buckets module
│   ├── database/                 # RDS module
│   │   └── {main,variables,outputs,data-blocks}.tf
│   ├── dns/                      # Route53 + ACM modules
│   │   ├── route53/
│   │   └── acm/
│   └── root/                     # Per-environment root workspaces (one per concern)
│       ├── dev/{networking,iam-roles,s3,ecr,eks,database,dns}/
│       │   └── {main,variables,providers,backend,data-blocks}.tf
│       └── prod/{networking,iam-roles,s3,eks}/
│           └── {main,variables,providers,backend}.tf
│
├── .github/                      # CI/CD
│   └── workflows/
│       ├── portfolio-images.yaml # Build + push api & web images to ECR
│       ├── helmchart.yaml        # Lint + publish Helm chart to ECR OCI
│       ├── deploy-workflow.yaml  # Terraform plan/apply orchestration
│       ├── validation-PT.yaml    # Platform-tools manifest validation
│       └── README.md
│
├── scripts/                      # Bootstrap & operational helpers
│   ├── bootstrap-flux.sh
│   ├── cluster-creation.sh
│   ├── destroy-cluster.sh
│   ├── tools-installation.sh
│   └── validation.sh
│
├── docs/                         # Operator documentation
│   └── runbooks/
│
├── .planning/                    # GSD planning artifacts (this directory)
│   └── codebase/
│
├── CLAUDE.md                     # Project context for Claude
├── SECURITY-AUDIT.md             # Audit findings (top-level deliverable)
├── README.md
├── interview-star-questions.md
├── .trivyignore
└── .gitignore
```

## Directory Purposes

**`app/portfolio/`:**
- Purpose: Source code for the two runtime services.
- Contains: `frontend/` (Express + helmet + http-proxy-middleware), `api/` (Flask + flask-cors + smtplib).
- Key files: `app/portfolio/frontend/server.js`, `app/portfolio/api/app.py`, both Dockerfiles.

**`HelmCharts/portfolio/`:**
- Purpose: The Helm chart packaging the app for Kubernetes. Published to `oci://372517046622.dkr.ecr.us-east-1.amazonaws.com/helm-charts/` by `.github/workflows/helmchart.yaml`.
- Contains: Two-template chart (api, frontend) + sealed-secret for SMTP.
- Key files: `HelmCharts/portfolio/Chart.yaml`, `HelmCharts/portfolio/values.yaml`, `HelmCharts/portfolio/templates/01-backend.yaml`.

**`portfolio/`:**
- Purpose: Glue between the chart and the cluster — declares which chart version + values to install, plus ingress routing.
- Contains: `base/` (namespace, HelmRepository, HelmRelease, VirtualService), `overlays/{dev,prod}/` for env tweaks, `image-automation/` for Flux image bumps.
- Key files: `portfolio/base/helmrelease.yaml` (the source of truth for what's running), `portfolio/base/virtualservice.yaml`.

**`platform-tools/`:**
- Purpose: All cluster-wide infrastructure as Kustomize bases with `dev`/`prod` overlays.
- Contains: One subdirectory per tool. Istio and Karpenter are split into multiple sub-components with explicit `dependsOn` in their cluster bindings.
- Key files: `platform-tools/istio/istio-ingress/base/gateway.yaml`, `platform-tools/karpenter/nodepool/base/`.

**`clusters/`:**
- Purpose: The Flux entry point — each subdirectory represents one cluster, holds the Flux components and a Kustomization per platform tool / app.
- Contains: `dev-projectx/` (live), `test/` (scaffold).
- Key files: `clusters/dev-projectx/flux-system/gotk-sync.yaml` (root GitRepository + Kustomization), every `clusters/dev-projectx/<tool>.yaml`.

**`terraform-infra/`:**
- Purpose: All AWS provisioning. Modules at top level; per-environment composition under `root/{dev,prod}/<workspace>/`.
- Contains: One module per concern; one root workspace per concern per environment (each with its own remote state backend).
- Key files: `terraform-infra/eks-cluster/eks.tf`, `terraform-infra/root/dev/eks/main.tf`, `terraform-infra/iam-role-module/Policies/*.json`.

**`.github/workflows/`:**
- Purpose: CI/CD pipelines — the only path images, charts, and infrastructure reach AWS.
- Key files: `.github/workflows/portfolio-images.yaml` (matrix Docker build), `.github/workflows/helmchart.yaml` (Helm OCI publish), `.github/workflows/deploy-workflow.yaml` (Terraform).

**`scripts/`:**
- Purpose: Day-1 bootstrap helpers (cluster creation, Flux bootstrap, validation). Not part of the steady-state GitOps loop.

**`docs/runbooks/`:**
- Purpose: Operator runbooks for incident response and routine ops.

**`.planning/`:**
- Purpose: GSD workflow artifacts (this analysis lives here).

## Key File Locations

**Entry points:**
- `app/portfolio/frontend/server.js` — Frontend HTTP server (port 3000).
- `app/portfolio/api/app.py` — Backend Flask app (port 5000 in code; 8000 in chart values — see CONCERNS).
- `clusters/dev-projectx/flux-system/gotk-sync.yaml` — GitOps root.
- `terraform-infra/root/dev/eks/main.tf` — EKS provisioning entry.

**Configuration:**
- `HelmCharts/portfolio/values.yaml` — Chart defaults.
- `portfolio/base/helmrelease.yaml` — Live values overrides (image tags, replicas, resources).
- `app/portfolio/{frontend,api}/.env.example` — Local env templates.
- `terraform-infra/root/dev/<workspace>/{variables.tf,terraform.tfvars}` — Terraform inputs.
- `terraform-infra/root/dev/<workspace>/backend.tf` — Remote-state config.

**Core logic:**
- `app/portfolio/api/app.py` — Validation, rate-limit, SMTP send.
- `app/portfolio/frontend/server.js` — CSP, compression, `/api/*` proxy, SPA fallback.
- `terraform-infra/eks-cluster/` — EKS module (cluster + ASG + addons + IRSA + Flux bootstrap).
- `terraform-infra/iam-role-module/` — Reusable IAM role factory.

**Routing & ingress:**
- `portfolio/base/virtualservice.yaml` — App routing rules.
- `platform-tools/istio/istio-ingress/base/gateway.yaml` — Gateway listeners.
- `terraform-infra/dns/route53/`, `terraform-infra/dns/acm/` — DNS + TLS.

**CI/CD:**
- `.github/workflows/portfolio-images.yaml`, `helmchart.yaml`, `deploy-workflow.yaml`, `validation-PT.yaml`.

**Security artifacts:**
- `SECURITY-AUDIT.md` (top-level).
- `terraform-infra/iam-role-module/Policies/*.json` (least-privilege IAM policies).
- `HelmCharts/portfolio/templates/sealed-secret.yaml` (encrypted SMTP creds).
- `clusters/dev-projectx/flux-system/networkpolicy.yaml` (Flux NetworkPolicy).
- `.trivyignore` (CVE allow-list).

## Naming Conventions

**Files:**
- Terraform: split per concern — `main.tf`, `variables.tf`, `outputs.tf`, `providers.tf`, `backend.tf`, `data-blocks.tf`.
- Kubernetes manifests: ordered prefix when load order matters (`01-backend.yaml`, `02-frontend.yaml`); otherwise singular noun (`virtualservice.yaml`, `helmrelease.yaml`, `namespace.yaml`).
- Cluster bindings: one file per platform tool (`istio.yaml`, `karpenter.yaml`, etc.) at `clusters/dev-projectx/`.
- Workflows: `kebab-case.yaml` under `.github/workflows/`.
- Shell: `kebab-case.sh` under `scripts/`.

**Directories:**
- `kebab-case` for multi-word (`platform-tools`, `aws-lb-controller`, `sealed-secrets`, `eks-monitoring`).
- `lowercase` single word elsewhere (`networking`, `database`, `bootstrap`).
- Every platform tool follows the **`base/` + `overlays/{dev,prod}/`** Kustomize convention.
- Terraform follows **module-at-top + `root/<env>/<workspace>/`**.

**Resources:**
- Kubernetes: `kebab-case` (`portfolio-api`, `portfolio-frontend`, `portfolio-smtp`, `main-gateway`, `ecr-charts`).
- Terraform: `snake_case` (`aws_eks_cluster.projectx_cluster`, `module.eks`).
- IAM policy JSONs: `snake_case_policy.json`.

## Where to Add New Code

**New runtime feature in the portfolio app:**
- Backend logic: extend `app/portfolio/api/app.py` (Flask routes; keep `/api/` prefix for VirtualService routing).
- Frontend: edit `app/portfolio/frontend/public/{index.html,js/main.js,css/style.css}`; routes/proxy in `server.js`.
- Tests: no test directory exists yet — add `app/portfolio/api/tests/` (pytest cache present) or `app/portfolio/frontend/tests/`.
- After change, CI (`.github/workflows/portfolio-images.yaml`) builds + tags by SHA on push to `main`.
- Bump image SHA in `portfolio/base/helmrelease.yaml` (or rely on Flux image-automation under `portfolio/image-automation/base/`).

**New Helm chart change (e.g. new env var, new resource):**
- Edit `HelmCharts/portfolio/templates/*.yaml` and `HelmCharts/portfolio/values.yaml`.
- Bump `HelmCharts/portfolio/Chart.yaml` `version:` (semver).
- `.github/workflows/helmchart.yaml` will lint + publish to ECR OCI on merge.
- Bump `chart.spec.version` in `portfolio/base/helmrelease.yaml` to consume the new chart.

**New platform tool (e.g. cert-manager):**
- Create `platform-tools/<tool>/base/{namespace.yaml,helmrepository.yaml,helmrelease.yaml,kustomization.yaml}`.
- Add `platform-tools/<tool>/overlays/{dev,prod}/kustomization.yaml`.
- Bind it to the cluster: create `clusters/dev-projectx/<tool>.yaml` (Flux Kustomization pointing at `./platform-tools/<tool>/overlays/dev`), with `dependsOn:` if needed.

**New environment-specific override:**
- Edit/create `platform-tools/<tool>/overlays/<env>/patch.yaml` and reference it from that overlay's `kustomization.yaml`.
- For the app: `portfolio/overlays/<env>/patch.yaml`.

**New AWS infrastructure:**
- If reusable: create a new module dir at `terraform-infra/<name>/` with `main.tf`, `variables.tf`, `outputs.tf`.
- For environment use: create `terraform-infra/root/<env>/<workspace>/` with `main.tf` (calling the module), `variables.tf`, `providers.tf`, and `backend.tf` (S3 remote state).
- Add a workspace target to `.github/workflows/deploy-workflow.yaml`.
- For new IAM policies: drop JSON in `terraform-infra/iam-role-module/Policies/` and reference via the module.

**New IRSA-bound controller:**
- Add policy JSON to `terraform-infra/iam-role-module/Policies/`.
- Provision role via `iam-role-module` from the appropriate root workspace.
- Reference the role ARN in the controller's `serviceAccount.annotations` in `platform-tools/<tool>/base/helmrelease.yaml`.

**New secret:**
- Never commit raw secrets. Generate a SealedSecret with `kubeseal` against the in-cluster controller's public key.
- Commit under the consuming chart's `templates/` (e.g. `HelmCharts/portfolio/templates/sealed-secret.yaml` pattern) or the relevant Kustomize base.

**New CI workflow:**
- Add `.github/workflows/<name>.yaml` with path filters; reuse OIDC pattern (`permissions.id-token: write`, `aws-actions/configure-aws-credentials@v4` with `role-to-assume: ${{ vars.IAM_ROLE }}`).
- If it's a required gate, add to `github_branch_protection_v3.main.required_status_checks.contexts` in `terraform-infra/root/dev/eks/main.tf`.

**New runbook / docs:**
- Operator runbooks: `docs/runbooks/<name>.md`.
- Top-level audit findings: append to `SECURITY-AUDIT.md`.

## Special Directories

**`.planning/`:**
- Purpose: GSD command artifacts (codebase analysis, phases).
- Generated: Yes (by `/gsd-*` commands).
- Committed: Yes.

**`.planning.bak.<timestamp>/`:**
- Purpose: Backup of a prior planning session.
- Generated: Yes.
- Committed: Currently yes — candidate for cleanup / move to `.gitignore`.

**`.terraform/` (under each TF workspace):**
- Purpose: Terraform plugin cache and local state.
- Generated: Yes.
- Committed: No (ignored).

**`node_modules/` (`app/portfolio/frontend/`):**
- Purpose: npm dependencies.
- Generated: Yes.
- Committed: No.

**`__pycache__/`, `.pytest_cache/`:**
- Purpose: Python bytecode / pytest cache.
- Generated: Yes.
- Committed: No (but `.pytest_cache/` is present at repo root and `app/portfolio/api/` — check `.gitignore`).

**`clusters/test/`:**
- Purpose: Scaffold for a second cluster (only `flux-system/` present, no platform tools or app bindings yet).
- Generated: No.
- Committed: Yes.

**`HelmCharts/`:**
- Purpose: Charts authored in-repo and published to ECR. Distinct from `portfolio/` which only consumes the chart via HelmRelease.

---

*Structure analysis: 2026-04-15*
