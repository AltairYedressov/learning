# Roadmap: ProjectX Infrastructure Security Audit

## Overview

This roadmap transforms the ProjectX EKS platform from its current state (documented security gaps in CONCERNS.md) to production-ready hardened infrastructure. The sequence follows a strict audit-before-enforce discipline: scanners run first to produce findings, fixes are applied layer by layer (network, pod, app), policy enforcement activates only after violations are pre-remediated, and access control is hardened last due to lockout risk. Every phase is discussed collaboratively before remediation.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Audit Baseline** - Run CIS benchmark scan and document all findings before any changes
- [ ] **Phase 2: CI/CD Security Gate** - Block vulnerable images and misconfigured IaC before they reach the cluster
- [ ] **Phase 3: Network Security** - Enforce network isolation with deny-default policies, scoped security groups, and strict mTLS
- [ ] **Phase 4: Pod Security Hardening** - Apply security contexts to all workload pods
- [ ] **Phase 5: Application Security** - Fix CORS, add rate limiting, and enforce input validation on the backend
- [ ] **Phase 6: Kyverno Policy Engine** - Deploy admission control in audit mode, review, then enforce
- [ ] **Phase 7: IAM & RBAC Hardening** - Tighten RBAC bindings, scope IRSA roles, and strip excessive node permissions
- [ ] **Phase 8: Secrets & Encryption** - Enable KMS encryption at rest and enforce Sealed Secrets for all secret management

## Phase Details

### Phase 1: Audit Baseline
**Goal**: Establish a complete findings baseline that drives all subsequent hardening work
**Depends on**: Nothing (first phase)
**Requirements**: EKS-01
**Success Criteria** (what must be TRUE):
  1. kube-bench CIS EKS v1.7.0 scan has been executed and all critical/high findings are documented with pass/fail/N/A status
  2. AWS-managed controls marked as N/A are documented with rationale (not counted as failures)
  3. A prioritized findings list exists that maps each finding to a subsequent phase
**Plans:** 1 plan

Plans:
- [x] 01-01-PLAN.md -- Run kube-bench CIS EKS v1.7.0 scan, build unified FINDINGS.md with phase mappings

### Phase 2: CI/CD Security Gate
**Goal**: No vulnerable container images or misconfigured Terraform can reach the cluster through CI/CD
**Depends on**: Phase 1
**Requirements**: CICD-01, CICD-02
**Success Criteria** (what must be TRUE):
  1. A pull request with a container image containing a CRITICAL CVE (with fix available) is blocked from merging
  2. A pull request with a Terraform misconfiguration flagged by Checkov is blocked from merging
  3. Trivy is pinned to v0.69.3 and trivy-action is pinned to commit SHA 57a97c7 (supply chain protection)
  4. CI pipeline scan results are visible in the GitHub Actions job output
**Plans:** 1 plan

Plans:
- [x] 02-01-PLAN.md -- Integrate Trivy image scanning + Checkov IaC scanning into CI workflows, add branch protection via Terraform

### Phase 3: Network Security
**Goal**: All cluster traffic is explicitly allowed or denied -- no implicit open access between namespaces or to the internet
**Depends on**: Phase 1
**Requirements**: NET-01, NET-02, NET-03
**Success Criteria** (what must be TRUE):
  1. Every namespace has a default-deny NetworkPolicy and pods can only communicate with explicitly allowed destinations
  2. DNS resolution (port 53 to kube-dns) and Istio sidecar ports (15012, 15001, 15006, 15090) continue to function after deny-all policies are applied
  3. Security group egress rules allow only required outbound destinations (no 0.0.0.0/0 egress on application security groups)
  4. Istio PeerAuthentication is STRICT across all namespaces and a plaintext HTTP request between services is rejected
**Plans:** 2/4 plans executed

Plans:
- [x] 03-01-PLAN.md -- Scope security group egress rules (Terraform module + root module)
- [x] 03-02-PLAN.md -- Portfolio NetworkPolicies + Istio STRICT mTLS PeerAuthentication + monitoring PERMISSIVE override
- [x] 03-03-PLAN.md -- Platform namespace NetworkPolicies (istio-ingress, istio-system, flux-system)
- [x] 03-04-PLAN.md -- Platform namespace NetworkPolicies (karpenter, monitoring, kube-system)

### Phase 4: Pod Security Hardening
**Goal**: Every workload pod runs with minimal OS-level privileges
**Depends on**: Phase 3
**Requirements**: EKS-03
**Success Criteria** (what must be TRUE):
  1. All pods run as non-root (runAsNonRoot: true) and no pod uses UID 0
  2. All pods have readOnlyRootFilesystem: true with emptyDir mounts for directories that require writes (e.g., /tmp)
  3. All pods drop ALL Linux capabilities and no pod requests privileged mode
  4. All workloads pass health checks and function correctly after security context changes
**Plans:** 2 plans

Plans:
- [x] 04-01-PLAN.md -- Portfolio Dockerfiles non-root user + Helm template security contexts
- [x] 04-02-PLAN.md -- EFK Elasticsearch + Kibana HelmRelease security context gap closure

### Phase 5: Application Security
**Goal**: The backend API rejects malicious input and restricts cross-origin access
**Depends on**: Phase 4
**Requirements**: APP-01, APP-02, APP-03
**Success Criteria** (what must be TRUE):
  1. CORS allows only specific origins and a request from an unauthorized origin is rejected
  2. API endpoints enforce rate limits and a burst of requests beyond the threshold returns 429 status codes
  3. API input payloads exceeding field constraints (max_length, invalid patterns) are rejected with validation errors
  4. Legitimate API requests from allowed origins continue to work normally
**Plans**: TBD

### Phase 6: Kyverno Policy Engine
**Goal**: An admission controller prevents non-compliant resources from being deployed to the cluster
**Depends on**: Phase 4, Phase 5
**Requirements**: EKS-02, POL-01, POL-02
**Success Criteria** (what must be TRUE):
  1. Kyverno is deployed via Flux and running in the cluster
  2. Pod Security Standard policies are active and PolicyReports show zero violations on existing workloads (because Phases 3-5 pre-remediated them)
  3. All Kyverno policies are stored in Git under the Flux Kustomization path and deployed via GitOps
  4. A test deployment violating Pod Security Standards is caught by Kyverno (audit mode reports the violation)
**Plans**: TBD

### Phase 7: IAM & RBAC Hardening
**Goal**: Cluster access follows least privilege with no unnecessary admin bindings or broad AWS permissions
**Depends on**: Phase 6
**Requirements**: IAM-01, IAM-02, IAM-03
**Success Criteria** (what must be TRUE):
  1. No unnecessary system:masters bindings exist and all ClusterRoleBindings are documented with justification
  2. Each IRSA service account has only the minimum AWS permissions required for its function (verified by comparing actual vs required permissions)
  3. Worker node IAM role no longer has AmazonEC2FullAccess or ElasticLoadBalancingFullAccess (replaced with scoped policies)
  4. aws-auth ConfigMap (or EKS Access Entries) is backed up before any modification and cluster access is verified after changes
**Plans**: TBD

### Phase 8: Secrets & Encryption
**Goal**: Kubernetes secrets are encrypted at rest using customer-managed keys and all secrets are managed exclusively through Sealed Secrets
**Depends on**: Phase 7
**Requirements**: EKS-04, EKS-05
**Success Criteria** (what must be TRUE):
  1. EKS cluster has KMS envelope encryption enabled for the secrets resource type
  2. A newly created secret is stored encrypted at rest (verified via AWS API or EKS configuration)
  3. Existing secrets are re-encrypted under the new KMS key (by recreating or rotating them)
  4. Every secret in Git is a SealedSecret resource -- no plain-text Secret manifests exist in any repository branch
  5. No secrets are created via manual kubectl create secret commands -- all secrets flow through kubeseal and GitOps
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Audit Baseline | 0/1 | Planning complete | - |
| 2. CI/CD Security Gate | 0/1 | Planning complete | - |
| 3. Network Security | 2/4 | In Progress|  |
| 4. Pod Security Hardening | 0/2 | Planning complete | - |
| 5. Application Security | 0/TBD | Not started | - |
| 6. Kyverno Policy Engine | 0/TBD | Not started | - |
| 7. IAM & RBAC Hardening | 0/TBD | Not started | - |
| 8. Secrets & Encryption | 0/TBD | Not started | - |
