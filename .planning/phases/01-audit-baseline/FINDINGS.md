# CIS EKS Benchmark v1.7.0 - Audit Findings

**Scan Date:** 2026-03-29
**Tool:** kube-bench v0.15.0
**Benchmark:** CIS EKS v1.7.0
**Cluster:** projectx (EKS, us-east-1, k8s v1.34.4)
**Nodes:** 3 (ip-10-0-1-78, ip-10-0-2-117, ip-10-0-3-86)

## Executive Summary

| Category | Count |
|----------|-------|
| PASS | 26 |
| FAIL | 1 |
| WARN | 19 |
| N/A (AWS-managed) | 5 |
| INFO | 0 |
| **Total Controls** | **46** |

**Critical/High FAIL findings:** 1
**WARN findings requiring review:** 19 (5 AWS-managed, 14 user-actionable)
**AWS-managed (not counted as failures per D-08):** 5

> **Note on WARN status:** kube-bench marks controls as WARN when they require manual verification. Many of these are Manual checks that kube-bench cannot automate. Each WARN finding below includes an assessment of whether it represents a real gap or is informational.

## CIS Findings by Section

### Section 2: Control Plane Configuration

| CIS ID | Description | Status | Scored | Severity | Remediation Phase |
|--------|-------------|--------|--------|----------|-------------------|
| 2.1.1 | Enable audit Logs | WARN | No | LOW | N/A -- Managed by AWS EKS -- not user-configurable. EKS control plane logging can be enabled via Terraform `cluster_enabled_log_types`. |
| 2.1.2 | Ensure audit logs are collected and managed | WARN | No | LOW | N/A -- Managed by AWS EKS -- not user-configurable. EKS sends audit logs to CloudWatch when enabled. |

**Section Summary:** 0 PASS, 0 FAIL, 2 WARN. Both controls are AWS-managed (EKS control plane audit logging). These are not user-configurable at the node level but can be enabled via Terraform EKS module settings.

### Section 3: Worker Nodes

| CIS ID | Description | Status | Scored | Severity | Remediation Phase |
|--------|-------------|--------|--------|----------|-------------------|
| 3.1.1 | Ensure that the kubeconfig file permissions are set to 644 or more restrictive | PASS | Yes | -- | -- |
| 3.1.2 | Ensure that the kubelet kubeconfig file ownership is set to root:root | PASS | Yes | -- | -- |
| 3.1.3 | Ensure that the kubelet configuration file has permissions set to 644 or more restrictive | PASS | Yes | -- | -- |
| 3.1.4 | Ensure that the kubelet configuration file ownership is set to root:root | PASS | Yes | -- | -- |
| 3.2.1 | Ensure that the Anonymous Auth is Not Enabled | PASS | Yes | -- | -- |
| 3.2.2 | Ensure that the --authorization-mode argument is not set to AlwaysAllow | PASS | Yes | -- | -- |
| 3.2.3 | Ensure that a Client CA File is Configured | PASS | Yes | -- | -- |
| 3.2.4 | Ensure that the --read-only-port is disabled | PASS | Yes | -- | -- |
| 3.2.5 | Ensure that the --streaming-connection-idle-timeout argument is not set to 0 | PASS | Yes | -- | -- |
| 3.2.6 | Ensure that the --make-iptables-util-chains argument is set to true | PASS | Yes | -- | -- |
| 3.2.7 | Ensure that the --eventRecordQPS argument is set to 0 or a level which ensures appropriate event capture | PASS | Yes | -- | -- |
| 3.2.8 | Ensure that the --rotate-certificates argument is not present or is set to true | PASS | Yes | -- | -- |
| 3.2.9 | Ensure that the RotateKubeletServerCertificate argument is set to true | PASS | Yes | -- | -- |

**Section Summary:** 13 PASS, 0 FAIL, 0 WARN. All worker node checks pass. EKS-managed AMIs configure kubelet securely by default.

### Section 4: Policies

| CIS ID | Description | Status | Scored | Severity | Remediation Phase |
|--------|-------------|--------|--------|----------|-------------------|
| 4.1.1 | Ensure that the cluster-admin role is only used where required | **FAIL** | Yes | **HIGH** | Phase 7: IAM & RBAC Hardening |
| 4.1.2 | Minimize access to secrets | PASS | Yes | -- | -- |
| 4.1.3 | Minimize wildcard use in Roles and ClusterRoles | PASS | Yes | -- | -- |
| 4.1.4 | Minimize access to create pods | PASS | Yes | -- | -- |
| 4.1.5 | Ensure that default service accounts are not actively used | PASS | Yes | -- | -- |
| 4.1.6 | Ensure that Service Account Tokens are only mounted where necessary | PASS | Yes | -- | -- |
| 4.1.7 | Cluster Access Manager API to streamline and enhance the management of access controls within EKS clusters | WARN | No | MEDIUM | Phase 7: IAM & RBAC Hardening. Note: Verify EKS auth mode (aws-auth vs Access Entries API) per STATE.md blocker. |
| 4.1.8 | Limit use of the Bind, Impersonate and Escalate permissions in the Kubernetes cluster | WARN | No | MEDIUM | Phase 7: IAM & RBAC Hardening |
| 4.2.1 | Minimize the admission of privileged containers | PASS | Yes | -- | -- |
| 4.2.2 | Minimize the admission of containers wishing to share the host process ID namespace | PASS | Yes | -- | -- |
| 4.2.3 | Minimize the admission of containers wishing to share the host IPC namespace | PASS | Yes | -- | -- |
| 4.2.4 | Minimize the admission of containers wishing to share the host network namespace | PASS | Yes | -- | -- |
| 4.2.5 | Minimize the admission of containers with allowPrivilegeEscalation | PASS | Yes | -- | -- |
| 4.3.1 | Ensure CNI plugin supports network policies | WARN | No | MEDIUM | Phase 3: Network Security. Note: Verify Istio port configuration per STATE.md blocker. |
| 4.3.2 | Ensure that all Namespaces have Network Policies defined | PASS | Yes | -- | -- |
| 4.4.1 | Prefer using secrets as files over secrets as environment variables | PASS | Yes | -- | -- |
| 4.4.2 | Consider external secret storage | WARN | No | MEDIUM | Phase 8: Secrets & Encryption |
| 4.5.1 | Create administrative boundaries between resources using namespaces | WARN | No | LOW | Acknowledged -- namespaces already in use (portfolio, istio-system, flux-system, kube-system, etc.) |
| 4.5.2 | The default namespace should not be used | PASS | Yes | -- | -- |

**Section Summary:** 13 PASS, 1 FAIL, 5 WARN. The single FAIL (4.1.1 cluster-admin overuse) is the only scored failure in the entire scan. Manual WARN checks require review in Phases 3, 7, and 8.

### Section 5: Managed Services

| CIS ID | Description | Status | Scored | Severity | Remediation Phase |
|--------|-------------|--------|--------|----------|-------------------|
| 5.1.1 | Ensure Image Vulnerability Scanning using Amazon ECR image scanning or a third party provider | WARN | No | HIGH | Phase 2: CI/CD Security Gate. Note: Trivy v0.69.4 is supply-chain compromised per STATE.md blocker -- must pin to v0.69.3. |
| 5.1.2 | Minimize user access to Amazon ECR | WARN | No | MEDIUM | Phase 7: IAM & RBAC Hardening |
| 5.1.3 | Minimize cluster access to read-only for Amazon ECR | WARN | No | MEDIUM | Phase 7: IAM & RBAC Hardening |
| 5.1.4 | Minimize Container Registries to only those approved | WARN | No | MEDIUM | Phase 6: Kyverno Policy Engine |
| 5.2.1 | Prefer using dedicated Amazon EKS Service Accounts | WARN | No | MEDIUM | Phase 7: IAM & RBAC Hardening |
| 5.3.1 | Ensure Kubernetes Secrets are encrypted using Customer Master Keys (CMKs) managed in AWS KMS | WARN | No | HIGH | Phase 8: Secrets & Encryption |
| 5.4.1 | Restrict Access to the Control Plane Endpoint | WARN | No | HIGH | N/A -- Managed by AWS EKS -- not user-configurable at node level. Can be restricted via Terraform EKS endpoint access settings. Phase 7: IAM & RBAC Hardening. |
| 5.4.2 | Ensure clusters are created with Private Endpoint Enabled and Public Access Disabled | WARN | No | HIGH | N/A -- Managed by AWS EKS -- not user-configurable at node level. Configurable via Terraform but requires architecture change. Phase 7: IAM & RBAC Hardening. |
| 5.4.3 | Ensure clusters are created with Private Nodes | WARN | No | HIGH | Acknowledged risk -- User decision -- nodes in public subnets for learning project simplicity. Mitigated by security groups. |
| 5.4.4 | Ensure Network Policy is Enabled and set as appropriate | WARN | No | HIGH | Phase 3: Network Security |
| 5.4.5 | Encrypt traffic to HTTPS load balancers with TLS certificates | WARN | No | MEDIUM | Acknowledged -- Already implemented. Istio Gateway terminates TLS via ACM certificate on AWS NLB. |
| 5.5.1 | Manage Kubernetes RBAC users with AWS IAM Authenticator for Kubernetes or Upgrade to AWS CLI v1.16.156 or greater | WARN | No | MEDIUM | Phase 7: IAM & RBAC Hardening |

**Section Summary:** 0 PASS, 0 FAIL, 12 WARN. All Managed Services controls are manual checks. Several are AWS-managed (5.4.1, 5.4.2), one is an acknowledged risk (5.4.3 private nodes), and one is already mitigated (5.4.5 TLS).

## Application & Platform Findings (from CONCERNS.md)

These findings come from the pre-existing codebase security analysis, not from CIS benchmark scanning. They are kept in a separate section per D-11.

| ID | Description | Severity | Remediation Phase |
|----|-------------|----------|-------------------|
| S1 | Frontend API URL exposed in pod spec | LOW | Acknowledged (non-secret) |
| S2 | No NetworkPolicies for portfolio | HIGH | Phase 3: Network Security |
| S3 | No Pod Security Standards on portfolio | HIGH | Phase 4: Pod Security Hardening |
| S4 | No image pull secrets or registry enforcement | MEDIUM | Phase 6: Kyverno Policy Engine |
| S5 | Backend Uvicorn running without SSL | MEDIUM | Acknowledged (Istio mTLS mitigates pod-to-pod encryption) |
| T1 | CORS wildcard configuration (`allow_origins=["*"]`) | HIGH | Phase 5: Application Security |
| T5 | Missing backend input validation (no Pydantic Field constraints) | MEDIUM | Phase 5: Application Security |
| T6 | No rate limiting or API authentication | HIGH | Phase 5: Application Security |
| TC5 | No container image scanning in CI/CD pipeline | HIGH | Phase 2: CI/CD Security Gate |

## Prioritized Remediation Summary

### FAIL and Critical WARN Findings by Remediation Phase

| Phase | Finding IDs | Count |
|-------|-------------|-------|
| Phase 2: CI/CD Security Gate | 5.1.1, TC5 | 2 |
| Phase 3: Network Security | 4.3.1, 5.4.4, S2 | 3 |
| Phase 4: Pod Security Hardening | S3 | 1 |
| Phase 5: Application Security | T1, T5, T6 | 3 |
| Phase 6: Kyverno Policy Engine | 5.1.4, S4 | 2 |
| Phase 7: IAM & RBAC Hardening | 4.1.1 (FAIL), 4.1.7, 4.1.8, 5.1.2, 5.1.3, 5.2.1, 5.4.1, 5.4.2, 5.5.1 | 9 |
| Phase 8: Secrets & Encryption | 4.4.2, 5.3.1 | 2 |
| Acknowledged Risks | 5.4.3 (public nodes), 5.4.5 (TLS already implemented), 4.5.1 (namespaces in use), S1, S5 | 5 |
| N/A (AWS-managed) | 2.1.1, 2.1.2 | 2 |

### Priority Order

1. **Phase 7: IAM & RBAC Hardening** -- 9 findings (includes the only scored FAIL: 4.1.1 cluster-admin overuse)
2. **Phase 3: Network Security** -- 3 findings (network policies and CNI verification)
3. **Phase 5: Application Security** -- 3 findings (CORS, input validation, rate limiting)
4. **Phase 2: CI/CD Security Gate** -- 2 findings (image scanning, note Trivy supply chain issue)
5. **Phase 6: Kyverno Policy Engine** -- 2 findings (registry enforcement)
6. **Phase 8: Secrets & Encryption** -- 2 findings (KMS encryption, external secrets)
7. **Phase 4: Pod Security Hardening** -- 1 finding (security contexts)

### STATE.md Blocker Cross-References

| Blocker | Related Findings | Impact |
|---------|-----------------|--------|
| Trivy v0.69.4 supply chain compromise | 5.1.1, TC5 | Phase 2 must pin Trivy to v0.69.3 and trivy-action to commit SHA 57a97c7 |
| EKS auth mode uncertainty (aws-auth vs Access Entries API) | 4.1.7, 5.5.1 | Phase 7 must verify auth mode before implementing RBAC changes |
| Istio port configuration verification | 4.3.1, 5.4.4 | Phase 3 must verify Istio port config before NetworkPolicy rollout |

## Overall Assessment

The ProjectX EKS cluster is in **good baseline condition** for a learning/development environment:

- **Worker nodes (Section 3):** All 13 checks PASS. EKS-managed AMIs provide secure kubelet defaults.
- **Policies (Section 4):** 1 scored FAIL (cluster-admin overuse). Pod security admission is properly configured. RBAC manual checks need Phase 7 review.
- **Managed Services (Section 5):** All 12 are manual WARN checks. Key gaps: no image scanning, no KMS encryption for secrets, public endpoint access, public nodes (acknowledged).
- **Application layer:** CORS wildcard, no rate limiting, and no network policies are the highest-severity application findings.

The single scored FAIL (4.1.1) and the high-severity WARN findings (image scanning, secrets encryption, network policies) should be prioritized for remediation in Phases 2-8.

---

*Generated: 2026-03-29 from kube-bench CIS EKS v1.7.0 scan + CONCERNS.md analysis*
