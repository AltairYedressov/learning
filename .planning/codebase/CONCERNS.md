# Codebase Concerns

**Analysis Date:** 2026-04-15
**Scope:** ProjectX EKS platform — Terraform (`terraform-infra/`), GitOps manifests (`clusters/`, `platform-tools/`, `portfolio/`, `HelmCharts/`), CI/CD (`.github/workflows/`), shell scripts (`scripts/`)
**Reference:** `SECURITY-AUDIT.md` (2026-03-23) is the canonical living audit. This document re-derives findings from current source state, cross-checks the audit, and surfaces additional concerns.

---

## Audit-Relevant Severity Snapshot

| Severity | Count | Top examples |
|----------|-------|--------------|
| CRITICAL | 8     | Public EKS API endpoint, GitHub PAT in TF state, plaintext Kibana key, auto-approve apply |
| HIGH     | 18    | Wildcard IAM, hardcoded account IDs, EFK plaintext, unpinned Actions/AMI/images |
| MEDIUM   | 25+   | Workers in public subnets (constraint), missing IMDSv2, partial control-plane logs, no VPC flow logs |
| LOW      | 12    | Region hardcoded, no permission boundaries, sleep-instead-of-wait, missing doc headers |

Counts and per-finding remediation steps maintained in `SECURITY-AUDIT.md`. Items below add detail and confirm presence in the current tree.

---

## Security Concerns — Network / VPC

### N1. EKS API Server Publicly Reachable
- Risk: Cluster control plane open to the internet; brute-force / credential-stuffing surface.
- Files: `terraform-infra/eks-cluster/eks.tf:12` (`endpoint_public_access = true`)
- Current mitigation: None — no `public_access_cidrs`, no private endpoint.
- Fix approach: Set `endpoint_private_access = true`; restrict `public_access_cidrs` to admin/CI egress IPs (CI uses GitHub-hosted runners → cannot pin IPs cleanly; consider self-hosted runner in VPC or AWS-hosted runners).

### N2. Worker Nodes in Public Subnets (Accepted Constraint)
- Risk: Worker EC2s receive public IPs; SSRF / IMDS abuse from compromised pod has direct internet path.
- Files: `terraform-infra/eks-cluster/data-blocks.tf:5-8`, `terraform-infra/eks-cluster/asg.tf:6` (`vpc_zone_identifier = data.aws_subnets.public.ids`), `terraform-infra/networking/subnets/subnets.tf:8` (`map_public_ip_on_launch`)
- Current mitigation: Worker SG only restricts ingress; egress to `0.0.0.0/0` for 443/53.
- Constraint: User has decided nodes must remain in public subnets. Compensating controls required: enforce IMDSv2 (see N3), tighten worker SG (N5), Network Policies on every namespace, restrict egress at SG and NetworkPolicy level, consider Istio egress gateway.

### N3. IMDSv2 Not Enforced on Worker Launch Template
- Risk: Pods can hit IMDSv1 to steal node IAM credentials (escalation path documented for SSRF in K8s clusters).
- Files: `terraform-infra/eks-cluster/launch-tm.tf` — no `metadata_options` block.
- Fix approach: Add `metadata_options { http_tokens = "required"; http_put_response_hop_limit = 1; http_endpoint = "enabled" }`. Hop limit of 1 prevents pods (which need 2) from hitting IMDS unless they use IRSA.

### N4. No VPC Flow Logs
- Risk: No network forensics. Lateral movement, exfiltration, scanning go unrecorded.
- Files: `terraform-infra/networking/vpc-module/vpc.tf` — no `aws_flow_log` resource.
- Fix approach: Add VPC flow log → CloudWatch or S3, retention >= 30 days.

### N5. Worker SG Allows All Protocols Self-Reference + Wide Egress
- Risk: A compromised pod on one node has full L3/L4 reach to all other nodes; egress 0.0.0.0/0 on 443/53 enables C2 / data exfil.
- Files: `terraform-infra/root/dev/networking/main.tf:118-126` (self ingress `protocol = "-1"`), `:59-77` (egress to 0.0.0.0/0).
- Fix approach: Restrict node-to-node to required CNI/kubelet/Istio ports (10250, 53, 4789 VXLAN if used, 15012/15017 for Istio control plane). Egress: scope to AWS service CIDRs (use VPC endpoints) where possible.

### N6. ALB SG Egress Mismatch (Functional + Security)
- Risk: ALB SG opens egress to 8080/8443 + NodePort range only, but Istio is fronted via NLB elsewhere; either dead config or hidden ALB exists.
- Files: `terraform-infra/root/dev/networking/main.tf:143-191`
- Fix approach: Audit whether ALB is still in use; if not, remove module. If yes, document.

### N7. Istio Gateway HTTPS Listener Declared as `protocol: HTTP`
- Risk: Listener on port 8443 is configured with `protocol: HTTP` (TLS terminated at NLB upstream). In-cluster traffic from NLB target → envoy on 8443 is plaintext; no envoy-side TLS validation; relying entirely on NLB target group.
- Files: `platform-tools/istio/istio-ingress/base/gateway.yaml:19-25`
- Fix approach: Either terminate TLS at envoy (`protocol: HTTPS` + `credentialName` referencing cert secret) or document NLB-pass-through model and ensure NLB listeners enforce TLS 1.2+ via ACM.

### N8. Database SG Allows Whole VPC CIDR
- Risk: Any pod or node in VPC can reach RDS on 3306; should be restricted to app SG or pods labeled `tier: backend`.
- Files: `terraform-infra/root/dev/networking/main.tf:128-141`
- Fix approach: Replace CIDR ingress with `referenced_security_group_id` from worker-nodes-sg, plus K8s NetworkPolicy in `portfolio` ns limiting egress to RDS.

---

## Security Concerns — EKS / Kubernetes

### K1. Incomplete EKS Control Plane Logging
- Risk: Cannot reconstruct authentication or scheduling decisions during incident response.
- Files: `terraform-infra/eks-cluster/eks.tf:5` — only `["api","audit"]`.
- Fix approach: Enable all log types: `["api","audit","authenticator","controllerManager","scheduler"]`.

### K2. Missing NetworkPolicies in Critical Namespaces
- Risk: Cluster defaults to allow-all pod-to-pod; lateral movement after pod compromise.
- Files: `platform-tools/karpenter/base/`, `platform-tools/velero/base/`, `platform-tools/thanos/base/`, `portfolio/base/` (no NetworkPolicy).
- Mitigation present: EFK stack now has policies (per `SECURITY-AUDIT.md` remediation list); flux-system has `networkpolicy.yaml`.
- Fix approach: Default-deny per namespace + allow-list manifests checked into each platform tool's `base/`.

### K3. Pod Security Contexts Missing
- Risk: Pods may run as root, with writable root FS, with capabilities; widens kernel exploit blast radius.
- Files: `platform-tools/karpenter/base/helmrelease.yaml`, `platform-tools/velero/base/helmrelease.yaml`, `portfolio/base/helmrelease.yaml` (no `securityContext`/`podSecurityContext` plumbed).
- Fix approach: Set `runAsNonRoot: true`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`, `allowPrivilegeEscalation: false` via HelmRelease values.

### K4. No Pod Security Admission / Kyverno Policies Enforced
- Risk: Kyverno is installed (`platform-tools/kyverno/`, `clusters/dev-projectx/kyverno.yaml`) but it is unclear which `audit`/`enforce` policies ship. Need to confirm baseline-restricted PSA labels on namespaces.
- Files: `platform-tools/kyverno/`, all namespace manifests under `portfolio/base/namespace.yaml`.
- Fix approach: Apply `pod-security.kubernetes.io/enforce=restricted` labels on app namespaces; ship Kyverno cluster policies for image registry allow-list, no `:latest`, no `hostPath`, runAsNonRoot.

### K5. Unpinned Image Tags
- Risk: Untested upstream changes silently rolled out; supply-chain risk.
- Files:
  - `platform-tools/velero/overlays/dev/patch.yaml:13` (`tag: "latest"`)
  - `platform-tools/karpenter/nodepool/base/nodepool.yaml:41` (`alias: al2023@latest`)
  - `platform-tools/thanos/base/helmrelease.yaml:34` (`allowInsecureImages: true`)
- Fix approach: Pin to specific versions; mirror to private ECR; turn off insecure image policy.

### K6. Portfolio Pods Lack Probes / SecurityContext / NetworkPolicy
- Risk: Application namespace `portfolio` has only HelmRelease + VS; no NetworkPolicy, no PDB, no PodDisruptionBudget; image references confirmed pinned to SHA `42476509714ae08c779e1d7190d8842e0dfba1c5` (good).
- Files: `portfolio/base/helmrelease.yaml`, `HelmCharts/portfolio/templates/01-backend.yaml`, `02-frontend.yaml`
- Fix approach: Add liveness/readiness probes via chart values, NetworkPolicy in `portfolio` ns (allow ingress from istio-ingress only; egress to api svc + DNS + RDS).

### K7. Istio mTLS Mode Not Verified as STRICT
- Risk: `enableAutoMtls: true` permits mTLS but does not require it. Without a `PeerAuthentication { mtls.mode: STRICT }`, plaintext fallback is allowed.
- Files: `platform-tools/istio/istio-system/base/` (no PeerAuthentication shipped at this level), `portfolio/base/` (none).
- Fix approach: Add cluster-wide `PeerAuthentication` with `mtls.mode: STRICT` in `istio-system` namespace.

### K8. EFK Plaintext In-Cluster
- Risk: Logs (which often contain tokens, secrets, PII) transit Elasticsearch/Kibana/Fluent Bit in plaintext.
- Files: `platform-tools/efk-logging/base/helmrelease-elasticsearch.yaml:55,73-76`, `helmrelease-kibana.yaml:34,73`, `helmrelease-fluentbit.yaml:98`
- Acceptable in dev (per audit). Production MUST enable xpack security and TLS.

### K9. Kibana Encryption Key Hardcoded
- Risk: Saved-objects encryption is a placebo; Git history exposes the key.
- Files: `platform-tools/efk-logging/base/helmrelease-kibana.yaml:73` (`min-32-char-long-encryption-key!!`)
- Fix approach: Generate `openssl rand -base64 32`, store in SealedSecret, mount via env. Listed as **C3** in audit.

### K10. Sealed Secrets Dev Overlay Weakens Critical Component
- Risk: Sealed Secrets is the trust anchor for cluster secrets; dev overlay disables PDB, NetworkPolicy, sets debug logging.
- Files: `platform-tools/sealed-secrets/overlays/dev/patch.yaml:10-11,25-26`
- Fix approach: Treat as production-equivalent; keep PDB and NetworkPolicy on even in dev.

### K11. Karpenter Cluster Endpoint Hardcoded
- Risk: Cluster-name/endpoint coupling leaks account-specific value into manifest; rotation breaks deploy.
- Files: `platform-tools/karpenter/base/helmrelease.yaml:19,22` (also account ID line 19)
- Fix approach: Parameterize via overlay or external secrets/configmap.

### K12. Missing Flux Kustomization `healthChecks`
- Risk: Flux reports success on apply even if pods crashloop; no auto-rollback signal.
- Files: e.g. `clusters/dev-projectx/karpenter.yaml`, `portfolio.yaml`, others.
- Fix approach: Add `spec.healthChecks` referencing the HelmRelease + critical Deployments.

---

## Security Concerns — IAM / Access

### I1. Wildcard `Resource: "*"` in IAM Policies
- Risk: Privilege escalation if any pod assumes the role.
- Files: `terraform-infra/iam-role-module/Policies/karpenter_policy.json:5-24,26-39`, `velero_policy.json:4-15`
- Fix approach: Scope to cluster-tagged ARNs, e.g. `aws:ResourceTag/karpenter.sh/discovery: ${cluster_name}`. For Karpenter `iam:*InstanceProfile`, restrict by name pattern.

### I2. GitHub Token Stored in Terraform State
- Risk: TF state in S3 contains plaintext PAT; anyone with `s3:GetObject` on state bucket gets repo write/admin access via that PAT.
- Files: `terraform-infra/eks-cluster/flux.tf:63,70` (`password = var.github_token`, `token = var.github_token`)
- Fix approach: Use Flux SSH deploy key (generate in TF, store private key in K8s Secret), or AWS CodeStar Connections, or GitHub App with installation token fetched per-run. Switch state bucket encryption to KMS CMK with restrictive key policy.

### I3. EKS Access Entries Pin Hardcoded ARNs
- Risk: ARNs and account ID embedded in code; rebuilding in another account requires text edits; no permission boundaries.
- Files: `terraform-infra/eks-cluster/access-entries.tf:9,15,25,31` (account `372517046622`)
- Fix approach: Variables for principal ARNs; `data.aws_caller_identity.current.account_id`.

### I4. No IAM Permission Boundaries
- Risk: Roles created via `iam-role-module` cannot exceed-but-also cannot be bounded to a maximum scope.
- Files: `terraform-infra/iam-role-module/main.tf:22-30`
- Fix approach: Add optional `permissions_boundary` arg; require for IRSA roles.

### I5. Hardcoded Account IDs (10+ Files)
- Risk: Account-coupled manifests; accidentally point production to dev resources.
- Files: see audit H2 table — TF + JSON policies + HelmReleases.
- Fix approach: TF — `data.aws_caller_identity`; manifests — Kustomize overlay variables or external-secrets/configmaps.

### I6. RDS Master User Auth via AWS Secrets Manager (Good) — But Backend Doesn't Use It
- Risk: `app/backend/main.py` returns hardcoded resume data; no DB code paths exist yet, but the secret-rotation pipeline / IRSA wiring for the future backend is undefined.
- Files: `terraform-infra/database/main.tf:20` (`manage_master_user_password = true`)
- Fix approach: When backend integrates with DB, plan for RDS IAM auth (`iam_database_authentication_enabled = true` already wired via variable), with IRSA role granting `rds-db:connect`.

### I7. Terraform Apply Auto-Approve Without Human Gate
- Risk: A push to `main` (or hijacked PR merge) silently mutates AWS infra including IAM and EKS.
- Files: `.github/workflows/deploy-workflow.yaml:99-106` (`terraform apply -auto-approve -input=false`)
- Fix approach: GitHub Environment with required reviewers protecting an `apply` job; split `plan` (uploads artifact) and `apply` (downloads + applies).

### I8. Workflow Permissions Over-broad
- Risk: `contents: write` not needed for checkout.
- Files: `.github/workflows/deploy-workflow.yaml:14-16`, `.github/workflows/validation-PT.yaml:9-11`
- Fix approach: Drop to `contents: read`. Keep `id-token: write` for OIDC.

### I9. Workflow-Level Secrets Exposure
- Risk: `GITHUB_TOKEN: ${{ secrets.FLUX_GITHUB_PAT }}` declared at workflow `env`, exposing it to every step including third-party Actions.
- Files: `.github/workflows/validation-PT.yaml:16`
- Fix approach: Move to step-level `env` only on `bootstrap-flux.sh` step.

---

## Security Concerns — CI/CD & GitOps

### C1. Curl-Pipe-To-Bash Supply Chain Vector
- Risk: Compromised CDN → arbitrary code execution on CI runner with OIDC role.
- Files: `scripts/tools-installation.sh:22` (`curl -s https://fluxcd.io/install.sh | sudo bash`); also `:9-11` eksctl from `latest`, `:16` kubectl from k8s.io without checksum.
- Fix approach: Pin versions, fetch SHA256 alongside, verify before executing. Prefer official setup actions with SHA-pinned versions.

### C2. GitHub Actions Not SHA-pinned
- Risk: Tag re-pointing or compromise of major version (`@v3`, `@v4`) → arbitrary code on runner.
- Files: `.github/workflows/deploy-workflow.yaml:43,47,53,63`, `.github/workflows/validation-PT.yaml:26,29`
- Fix approach: Pin all to commit SHAs. Use Renovate/Dependabot for managed updates.

### C3. Trigger Pattern Too Broad
- Risk: Any `feature/**` branch push triggers Terraform plan against real infra; an unrelated UI feature branch shouldn't touch TF state lock.
- Files: `.github/workflows/deploy-workflow.yaml:5-7`
- Fix approach: Path filter on `terraform-infra/**` AND/OR scope branch pattern (`feature/infra/**`).

### C4. Shell Script Hardening Missing
- Risk: Undefined-variable expansion, silent pipe failures, command injection on user-supplied vars.
- Files: All four `scripts/*.sh` use only `set -e`.
  - `scripts/cluster-creation.sh:21` — unquoted `$CLUSTER_NAME`.
  - `scripts/destroy-cluster.sh:8-9` — missing `\` continuation; `--wait` becomes a separate command.
  - `scripts/bootstrap-flux.sh:4-5,29` — params not validated for format.
- Fix approach: `set -euo pipefail`; quote all variables; validate input with `[[ "$X" =~ ^[a-z0-9-]+$ ]]`.

### C5. Validation Workflow Uses `sleep 120` Instead of Readiness
- Risk: Flaky validation; missed deploy regressions if the 120s isn't enough.
- Files: `.github/workflows/validation-PT.yaml:57`
- Fix approach: `kubectl wait --for=condition=Available deploy --all -n <ns> --timeout=600s` per critical namespace.

### C6. Ephemeral Cluster Tests Use eksctl-Created Clusters Outside Terraform
- Risk: Architectural drift — ephemeral test clusters are NOT defined in `terraform-infra/`; security baseline (logs, IRSA, KMS) won't match dev/prod.
- Files: `scripts/cluster-creation.sh`, `.github/workflows/validation-PT.yaml`
- Fix approach: Either (a) accept divergence and document, or (b) build ephemeral via Terraform workspace under `terraform-infra/root/test/`.

### C7. Flux Bootstrap Token-Auth With Personal PAT
- Risk: `--personal --token-auth` ties cluster GitOps to a single human's PAT; loss of person = loss of GitOps.
- Files: `scripts/bootstrap-flux.sh:31-37`
- Fix approach: GitHub App–based bootstrap, or deploy-key with read-only access.

### C8. State Bucket Encryption AES256, No KMS CMK
- Risk: TF state contains PAT (see I2) and other secrets; AWS-managed AES256 cannot enforce key access policy.
- Files: `terraform-infra/bootstrap/main.tf:13-20`
- Fix approach: KMS CMK with policy restricting `kms:Decrypt` to TF execution role only.

### C9. DynamoDB Lock Table Lacks PITR
- Risk: Accidental table delete = state-locking outage; though state itself is in S3 (versioned), recovery is painful.
- Files: `terraform-infra/bootstrap/main.tf:32-46`
- Fix approach: Enable `point_in_time_recovery { enabled = true }`.

---

## Tech Debt

- **Monolithic single-file services**: `app/backend/main.py` and `app/frontend/src/server.js` carry all logic. Acceptable for portfolio scope; flag for refactor when DB integration starts.
- **Hardcoded resume data in backend**: No DB connectivity yet, despite RDS being provisioned. RDS module exists ahead of consumer.
- **Multiple `app/` and `app/portfolio/` trees**: Two parallel app trees (`app/backend|frontend` and `app/portfolio/backend|frontend`); confirm which is the build source. `portfolio/base/helmrelease.yaml:25-26` references images `portfolio-api` / `portfolio-web`, suggesting the `app/portfolio/` tree is canonical and `app/backend|frontend` may be stale.
- **No linting / style enforcement**: No `.eslintrc`, `.pylintrc`, `ruff.toml`, `tflint.hcl`. Checkov runs in CI for Terraform; nothing for Python/JS.
- **No app-level tests**: No `*test*` directories under `app/`.
- **Helm chart values inconsistent with schema**: `HelmCharts/portfolio/Chart.yaml` exists; no `values.schema.json` enforces structure.
- **Spelling drift**: "Scurity Group for cluste" in `terraform-infra/root/dev/networking/main.tf:33,56,131` — minor but indicates lack of review.
- **DR config present but unused**: `terraform-infra/database/main.tf:83-123` defines DR replica + cross-region backups; gated by flags. Confirm whether intended for prod milestone.

## Fragile Areas

- **Flux bootstrap inside Terraform**: `flux_bootstrap_git` runs after EKS + ASG come up; ordering is manual via `depends_on`. If Flux provider fails post-EKS, partial bootstrap leaves cluster in inconsistent state, recovery requires manual `flux uninstall` + re-apply.
- **Single AZ risk in dev**: Need to confirm subnets span multi-AZ; check `terraform-infra/root/dev/networking/variables.tf` (not read here).
- **Karpenter using `al2023@latest`**: Auto-rolls AMI on every node refresh; one upstream AMI bug breaks all new nodes.
- **In-place HelmRelease upgrades on portfolio**: No canary / progressive delivery; bad chart version → all replicas rolling.
- **Test cluster creation diverges from prod IaC**: See C6.

## Incomplete Work

- **Production cluster manifests**: Only `clusters/dev-projectx/` and `clusters/test/` present. No `clusters/prod-projectx/`.
- **mTLS STRICT**: Not enforced (K7).
- **Backup restoration tested?**: Velero exists but no restore drill artifact.
- **Image signing / provenance**: ECR images pinned by SHA but no Cosign/Sigstore verification policy in Kyverno.
- **Secrets rotation**: Sealed secrets are committed to Git; no documented rotation cadence.
- **Audit log shipping**: EKS API/audit logs go to CloudWatch by default but no SIEM integration manifest.

## Hardcoded Values to Externalize

- AWS account `372517046622` — see audit H2 + `terraform-infra/eks-cluster/access-entries.tf`, `platform-tools/karpenter/base/helmrelease.yaml:19`, `platform-tools/velero/base/helmrelease.yaml:24,29`, etc.
- Region `us-east-1` — `scripts/cluster-creation.sh:11`, `scripts/destroy-cluster.sh:8`, workflow envs, multiple TF files (audit L1).
- Cluster endpoint URL — `platform-tools/karpenter/base/helmrelease.yaml:22`.
- Domain `yedressov.com` — `portfolio/base/virtualservice.yaml:8`, `platform-tools/istio/istio-ingress/base/gateway.yaml:17,24`. Acceptable but should be a Helm/Kustomize value for prod separation.
- Kibana encryption key — `platform-tools/efk-logging/base/helmrelease-kibana.yaml:73`.
- Cluster CIDR DNS `172.20.0.10` — `terraform-infra/eks-cluster/launch-tm.tf:32`.

## TODO / FIXME / HACK Markers

- No application-level TODOs in first-party code. All matches are in `node_modules` (vendored) and not actionable.

## Test Coverage Gaps

- **No unit/integration tests** for `app/backend/main.py` or `app/frontend/src/server.js`.
- **No Terraform tests** (`terraform test` blocks or Terratest).
- **No policy-as-code conformance tests** for Kyverno policies.
- **CI validation = `sleep 120` + `validation.sh`** — verify what `validation.sh` actually asserts; likely smoke-only.
- **No chaos / disruption tests** for HA claims (Karpenter draining, PDB enforcement).

## Scaling / Operational Limits

- **Karpenter without resource limits or PDB** on its own deployment (audit M11): if Karpenter pod dies during scaling event, no node provisioning until restart.
- **Single ES replica in dev** (audit L4): one node loss = log outage.
- **Flux reconcile interval 10m**: drift window of up to 10 minutes; acceptable but tune for prod.

---

## Cross-Reference to `SECURITY-AUDIT.md`

The findings above map to the audit ID scheme (C1–C8, H1–H10, M1–M16, L1–L8). All audit-listed remediations remain open at the time of this re-derivation, with these confirmations against current source state:

- C1, C4 confirmed in `eks.tf:12` and `deploy-workflow.yaml:102`.
- C2 confirmed in `flux.tf:63,70`.
- C6 confirmed in `cluster-creation.sh:21`; C7 confirmed in `destroy-cluster.sh:8-9`.
- H1 wildcard policies confirmed in JSON policy files (sample read).
- H8 confirmed: workflows still use `@v3` / `@v4` tags.
- M1 worker public-subnet placement confirmed in `asg.tf:6` (but this is an accepted user constraint — compensating controls required).
- M3 IMDSv2 absence confirmed: `launch-tm.tf` has no `metadata_options` block.
- New since audit: **N7** (Istio Gateway 8443 declared as `protocol: HTTP`).

---

*Concerns audit: 2026-04-15*
