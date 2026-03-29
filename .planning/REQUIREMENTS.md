# Requirements: ProjectX Infrastructure Security Audit

**Defined:** 2026-03-28
**Core Value:** Every layer of the infrastructure follows security best practices, with no critical or high-severity vulnerabilities remaining.

## v1 Requirements

### Network Security

- [ ] **NET-01**: All namespaces have default-deny NetworkPolicies with explicit allow-lists for required traffic
- [ ] **NET-02**: Security group egress rules restrict outbound traffic to required destinations only
- [ ] **NET-03**: Istio PeerAuthentication enforces STRICT mTLS across all namespaces (no plaintext fallback)

### EKS Cluster Hardening

- [x] **EKS-01**: CIS EKS Benchmark scan completed via kube-bench with all critical/high findings documented
- [ ] **EKS-02**: Pod Security Standards enforced via Kyverno in audit mode on all namespaces
- [ ] **EKS-03**: All pods have security contexts (runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities)
- [ ] **EKS-04**: EKS secrets encrypted at rest with KMS envelope encryption
- [ ] **EKS-05**: All Kubernetes secrets managed via Sealed Secrets — no plain-text Secret manifests in Git or manual kubectl create secret

### IAM & Access

- [ ] **IAM-01**: RBAC audited — no unnecessary system:masters bindings, ClusterRoleBindings follow least privilege
- [ ] **IAM-02**: All IRSA roles verified — each service account has minimal required AWS permissions
- [ ] **IAM-03**: Worker node IAM role stripped of AmazonEC2FullAccess and ElasticLoadBalancingFullAccess (replaced with scoped policies)

### CI/CD Security

- [ ] **CICD-01**: Trivy image vulnerability scanning integrated into CI pipeline, blocking critical/high CVEs
- [ ] **CICD-02**: Checkov IaC scanning integrated into CI pipeline for Terraform misconfigurations

### Application Security

- [ ] **APP-01**: Backend CORS restricted to specific allowed origins (no wildcard)
- [ ] **APP-02**: Rate limiting enabled on all public API endpoints
- [ ] **APP-03**: Pydantic models enforce field constraints (max_length, regex patterns) on all inputs

### Policy & Governance

- [ ] **POL-01**: Kyverno deployed via Flux with Pod Security Standard policy set in audit mode
- [ ] **POL-02**: All security policies stored in Git and deployed via Flux Kustomizations (policy-as-code)

## v2 Requirements

### Advanced Detection

- **DET-01**: Falco runtime threat detection deployed with custom rules for portfolio workloads
- **DET-02**: GuardDuty EKS integration enabled via Terraform
- **DET-03**: Kubescape continuous compliance monitoring deployed as operator

### Supply Chain

- **SC-01**: Container images signed with cosign in CI pipeline
- **SC-02**: Kyverno image verification policies enforce signed-only deployments
- **SC-03**: SBOM generation for every deployed image
- **SC-04**: Secret scanning in CI pipeline (trivy fs --scanners secret)

### Advanced Hardening

- **ADV-01**: GitHub Actions pinned to commit SHAs (not version tags)
- **ADV-02**: Istio AuthorizationPolicies for fine-grained service-to-service access control
- **ADV-03**: Kyverno policies promoted from audit to enforce mode

## Out of Scope

| Feature | Reason |
|---------|--------|
| Move nodes to private subnets | Explicit user decision — nodes stay in public subnets |
| Commercial security platforms (Prisma, Aqua) | Overkill for learning project, masks understanding |
| Custom admission webhooks | Use Kyverno instead — battle-tested, policy library included |
| Vault for secrets management | Heavy operational overhead, Sealed Secrets already deployed |
| Custom AMIs for host hardening | EKS-optimized AMIs already hardened by AWS |
| Automated remediation | Breaks collaborative fixing constraint — discuss each finding first |
| Zero-trust mesh replacement (Cilium) | Current Istio handles mTLS, replacing is scope creep |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| EKS-01 | Phase 1: Audit Baseline | Complete |
| CICD-01 | Phase 2: CI/CD Security Gate | Pending |
| CICD-02 | Phase 2: CI/CD Security Gate | Pending |
| NET-01 | Phase 3: Network Security | Pending |
| NET-02 | Phase 3: Network Security | Pending |
| NET-03 | Phase 3: Network Security | Pending |
| EKS-03 | Phase 4: Pod Security Hardening | Pending |
| APP-01 | Phase 5: Application Security | Pending |
| APP-02 | Phase 5: Application Security | Pending |
| APP-03 | Phase 5: Application Security | Pending |
| EKS-02 | Phase 6: Kyverno Policy Engine | Pending |
| POL-01 | Phase 6: Kyverno Policy Engine | Pending |
| POL-02 | Phase 6: Kyverno Policy Engine | Pending |
| IAM-01 | Phase 7: IAM & RBAC Hardening | Pending |
| IAM-02 | Phase 7: IAM & RBAC Hardening | Pending |
| IAM-03 | Phase 7: IAM & RBAC Hardening | Pending |
| EKS-04 | Phase 8: Secrets & Encryption | Pending |
| EKS-05 | Phase 8: Secrets & Encryption | Pending |

**Coverage:**
- v1 requirements: 18 total
- Mapped to phases: 18
- Unmapped: 0

---
*Requirements defined: 2026-03-28*
*Last updated: 2026-03-28 after roadmap revision (added EKS-05)*
