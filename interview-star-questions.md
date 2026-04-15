# STAR Interview Q&A — ProjectX Infrastructure Security Audit

Based on real work: AWS EKS platform security hardening across 7 phases, 13 plans, 18 requirements.

---

## 01 - Stable, Fast Infrastructure (3 Questions)

### Q1: Tell me about a time you ensured high availability for a production system.

**Situation:** Our EKS cluster ran portfolio services (Node.js frontend + FastAPI backend) with Istio service mesh, but had no pod disruption budgets, and platform tools like Kyverno and EFK logging could go down during node rotations — risking monitoring blind spots and policy enforcement gaps.

**Task:** Ensure all critical platform components maintain availability during voluntary disruptions (node upgrades, scaling events, deployments) without manual intervention.

**Action:** I deployed Kyverno with 2 replicas in production (1 in dev via Kustomize overlay) and configured PodDisruptionBudgets. For EFK logging, I hardened the Elasticsearch and Kibana HelmReleases with proper resource requests/limits and health probes. I used Karpenter for node autoscaling with automatic node replacement — so if a node is drained, workloads reschedule seamlessly. All deployments had readiness and liveness probes on `/health` endpoints, ensuring Kubernetes only routes traffic to healthy pods.

**Result:** Platform services survived node rotations with zero downtime. The combination of PDBs, multiple replicas, health probes, and Karpenter autoscaling meant the cluster self-maintained availability without operator intervention.

---

### Q2: Describe a situation where you improved the reliability of infrastructure through network-level hardening.

**Situation:** The EKS cluster had no NetworkPolicies — every pod could talk to every other pod across all 8 namespaces. A single compromised container could reach the database, monitoring stack, or GitOps controllers freely. This was both a security and a stability risk: a misbehaving pod could flood internal services.

**Task:** Implement cluster-wide network isolation so that each service only communicates with its explicitly defined dependencies, protecting both security and service stability.

**Action:** I rolled out default-deny NetworkPolicies across all 8 namespaces (portfolio, istio-system, istio-ingress, flux-system, karpenter, monitoring, kube-system, sealed-secrets). Each policy explicitly allowed only required traffic — for example, the backend only accepts ingress from the frontend and Istio gateway, and only has egress to DNS and the API server. I kept CoreDNS port 53 open from all pods for cluster DNS resolution, and made sure Istio sidecar ports (15012, 15001, 15006, 15090) remained functional. All policies were delivered via Flux GitOps.

**Result:** Every namespace achieved zero-trust networking. A compromised pod in the portfolio namespace cannot reach Elasticsearch, Flux controllers, or Karpenter. DNS and service mesh kept working — zero service disruptions during rollout. This eliminated lateral movement as an attack vector.

---

### Q3: Tell me about a time you enforced strict mTLS across a service mesh.

**Situation:** Istio was deployed with `enableAutoMtls: true`, which opportunistically upgrades connections to mTLS but still allows plaintext fallback. Any service without a sidecar could communicate in cleartext, and there was no enforcement that inter-service traffic was encrypted.

**Task:** Enforce STRICT mTLS across the entire mesh so that plaintext HTTP between services is rejected, while keeping monitoring functional (Prometheus scrapes metrics without mTLS).

**Action:** I deployed a mesh-wide `PeerAuthentication` resource in `istio-system` with mode STRICT, which rejects any plaintext connection between pods. For the monitoring namespace, I added a PERMISSIVE override so Prometheus could still scrape metrics endpoints without mTLS — a targeted exception rather than weakening the whole mesh. Both resources were managed via Flux Kustomizations.

**Result:** All inter-pod communication is now encrypted and authenticated via mTLS. A plaintext HTTP request between services is rejected. Prometheus continues to scrape metrics normally through the PERMISSIVE override. This fulfilled the NET-03 requirement and closed a gap flagged in the CIS audit.

---

## 02 - Deployment Automation (3 Questions)

### Q4: Tell me about a CI/CD pipeline you built that prevented vulnerabilities from reaching production.

**Situation:** Our GitHub Actions pipeline built Docker images and pushed them directly to ECR with no security scanning. Terraform changes deployed without IaC validation. A developer could merge a container with critical CVEs or a misconfigured security group into production.

**Task:** Build security gates into the CI/CD pipeline that block vulnerable images and misconfigured Terraform before they reach the cluster.

**Action:** I split the Docker pipeline into three stages: build, scan, push — the image only reaches ECR if Trivy finds zero CRITICAL/HIGH CVEs with available fixes. I pinned Trivy to v0.69.3 and the GitHub Action to commit SHA `57a97c7` because v0.69.4 was supply-chain compromised. For Terraform, I integrated Checkov before the plan stage, running without `--soft-fail` so misconfigurations hard-block the pipeline. I added Terraform-managed branch protection requiring all CI checks to pass before merge. A `.trivyignore` file tracks documented CVE exceptions.

**Result:** 100% of image and IaC changes are scanned before merge. Zero vulnerable images reach ECR. Developers see scan results directly in GitHub Actions output. The pipeline caught the Trivy supply-chain compromise before it could affect us.

---

### Q5: Describe how you implemented GitOps for a multi-tool platform deployment.

**Situation:** The EKS cluster needed 10+ platform tools deployed and continuously reconciled: Istio, Kyverno, EFK logging, Karpenter, Velero, AWS LB Controller, Sealed Secrets, Thanos, and the portfolio application. Manual `kubectl apply` or one-off Helm installs would create drift and make the cluster state unauditable.

**Task:** Implement a fully GitOps-driven deployment where every platform tool and application is defined in Git and automatically reconciled to the cluster.

**Action:** I used Flux CD with a base/overlay Kustomize pattern. Each tool has a `base/` directory with HelmRelease, NetworkPolicy, and any custom resources, plus `overlays/dev/` for environment-specific patches (like reducing replicas). The `clusters/dev-projectx/` directory contains Flux Kustomization resources that point to each tool's path. Flux reconciles every 10 minutes, and HelmReleases auto-rollback on failed upgrades. All security hardening (NetworkPolicies, PeerAuthentication, ClusterPolicies) was delivered through this same GitOps pipeline.

**Result:** The entire cluster state is defined in Git — fully auditable, reproducible, and self-healing. Any manual drift is corrected within 10 minutes. New security policies deploy through a PR, get reviewed, merge, and Flux applies them automatically. No `kubectl apply` commands needed for any platform changes.

---

### Q6: Tell me about a time you handled a supply-chain security risk in your deployment pipeline.

**Situation:** While integrating Trivy for container image scanning, I discovered that Trivy v0.69.4 had been supply-chain compromised. Our pipeline was about to pull and execute a malicious version of a security tool — the very tool meant to protect us.

**Task:** Secure the CI/CD pipeline against the compromised version while still maintaining vulnerability scanning capability.

**Action:** I pinned the Trivy binary to v0.69.3 (last known-good version) and pinned the `trivy-action` GitHub Action to a specific commit SHA (`57a97c7`) rather than a mutable tag. This way, even if upstream tags are moved or new compromised versions are published, our pipeline runs a verified version. I documented the decision in the project planning artifacts and added it as a standing constraint for future upgrades.

**Result:** The pipeline was protected from the supply-chain attack. This became a project-wide pattern — all security tooling is now pinned to specific versions or commit SHAs rather than floating tags. The incident was documented as a key decision so future engineers understand why the pin exists.

---

## 03 - Observability (2 Questions)

### Q7: How did you ensure observability wasn't broken by security hardening?

**Situation:** We were rolling out STRICT mTLS, default-deny NetworkPolicies, read-only root filesystems, and non-root security contexts across the entire cluster. Each of these changes risked breaking Prometheus metric scraping, Elasticsearch log ingestion, and Grafana dashboards — the tools operators rely on to detect issues.

**Task:** Harden the cluster without creating monitoring blind spots. Every security change had to preserve full observability.

**Action:** I took a layered approach: (1) For mTLS — I set a PERMISSIVE PeerAuthentication override specifically in the monitoring namespace so Prometheus can scrape without mTLS while the rest of the mesh stays STRICT. (2) For NetworkPolicies — every policy explicitly allows ingress from monitoring for metrics scraping (port 8080, 15090 for Envoy). The monitoring namespace itself has policies allowing Prometheus to reach all scrape targets and Grafana to accept ingress. (3) For pod hardening — EFK pods (Elasticsearch, Kibana) were given emptyDir `/tmp` volumes to handle transient writes with read-only root filesystems, preserving log pipeline functionality. (4) Health check endpoints (`/health`, `/readiness`) were exempted from rate limiting.

**Result:** Zero observability gaps after hardening. Prometheus scraping, Elasticsearch log ingestion, Kibana dashboards, and Grafana all continued functioning. Operators can still see everything — they just can't be attacked through the monitoring path.

---

### Q8: Describe how you implemented policy compliance reporting across a Kubernetes cluster.

**Situation:** After hardening pods, networks, and applications across 7 phases, we needed continuous compliance verification — not just a one-time audit. We had no mechanism to detect if a newly deployed workload violated Pod Security Standards.

**Task:** Deploy an admission controller that continuously audits the cluster against Pod Security Standards (Restricted) and generates compliance reports.

**Action:** I deployed Kyverno via Flux with a ClusterPolicy implementing Pod Security Standard (Restricted) in audit mode. The policy uses Kyverno's built-in `podSecurity` subrule covering: runAsNonRoot, drop ALL capabilities, readOnlyRootFilesystem, seccomp profile, and privilege escalation. Background scanning runs continuously against all namespaces — no exclusions, including kube-system. Violations are reported in PolicyReport CRDs that operators can query. I deliberately deployed Kyverno *after* Phases 3-5 pre-remediated violations, so the initial audit report was clean.

**Result:** Zero violations on existing workloads at deployment — confirming all prior hardening was effective. Kyverno generates PolicyReports that serve as continuous compliance evidence. AWS-managed pods in kube-system that violate Restricted standards are documented as expected (not remediable). Any new deployment violating standards is immediately flagged in the report.

---

## 04 - Auto-Scaling (2 Questions)

### Q9: Tell me about how you designed auto-scaling infrastructure that responds to demand without manual intervention.

**Situation:** The EKS cluster used Karpenter for node autoscaling, but after security hardening, Karpenter needed specific IAM permissions, network egress rules, and admission policy exemptions to function correctly. A misconfigured security control could silently break autoscaling — meaning traffic spikes wouldn't trigger new nodes.

**Task:** Ensure Karpenter continues to auto-scale nodes correctly after applying defense-in-depth security controls across the cluster.

**Action:** I carefully scoped each security layer to preserve Karpenter's function: (1) IAM — verified Karpenter's IRSA policy allows EC2 launch, fleet management, and IAM PassRole, all scoped to specific ARNs. The `iam:CreateInstanceProfile` action requires `Resource: "*"` because instance profiles are dynamically named — I documented this as an accepted exception. (2) NetworkPolicy — Karpenter's egress allows HTTPS to AWS APIs, DNS resolution, and webhook traffic. (3) Worker node IAM — when stripping overprivileged policies, I kept `AmazonEKS_CNI_Policy` which Karpenter-launched nodes need for CNI networking. (4) Kyverno — Karpenter pods were already compliant with Restricted PSS before the policy engine was deployed.

**Result:** Karpenter scales nodes from 0 to N based on pending pod demand with zero manual intervention. Security hardening didn't break any autoscaling path. The IRSA policy review confirmed all 4 custom IAM policies were well-scoped with ARN constraints — no changes needed.

---

### Q10: Describe how you balanced security constraints with the need for auto-scaling infrastructure.

**Situation:** When hardening worker node IAM roles, I needed to remove `AmazonEC2FullAccess` and `ElasticLoadBalancingFullAccess` — broad managed policies that gave worker nodes far more AWS permissions than needed. But these same nodes are launched by Karpenter and need certain EC2 permissions to join the cluster.

**Task:** Strip overprivileged IAM policies from worker nodes while ensuring Karpenter-provisioned nodes can still join the cluster and function normally.

**Action:** I analyzed which AWS API calls worker nodes actually make: `ec2:DescribeInstances` and `ec2:DescribeTags` for metadata lookups, plus CNI networking via `AmazonEKS_CNI_Policy`. I removed 3 broad managed policies (`AmazonEC2FullAccess`, `ElasticLoadBalancingFullAccess`, `AmazonEC2ContainerRegistryPowerUser`) and replaced them with a single custom policy granting only `ec2:DescribeInstances` and `ec2:DescribeTags`. ECR access was downgraded from PowerUser (push+pull) to ReadOnly (pull-only) since nodes only need to pull images. Karpenter's own IRSA role — separate from the node role — handles EC2 launch/terminate operations.

**Result:** Worker node IAM permissions reduced from 3 broad managed policies to 1 scoped custom policy + 2 minimal managed policies. Karpenter continues launching nodes that join the cluster successfully. The separation between Karpenter's IRSA role (launches nodes) and the node role (what nodes can do) meant I could aggressively strip node permissions without affecting scaling.

---

## 05 - Developer Efficiency (2 Questions)

### Q11: How did you make security enforcement transparent to developers?

**Situation:** We were adding 7 layers of security controls — NetworkPolicies, security contexts, CORS restrictions, rate limiting, Kyverno admission policies. Developers needed to ship features without becoming security experts or debugging why their pods can't start.

**Task:** Implement security enforcement that catches violations before production without creating friction in the development workflow.

**Action:** I designed the enforcement in layers of feedback: (1) CI/CD gates — Trivy and Checkov run on every PR, showing scan results directly in GitHub Actions output. Developers see exactly which CVE or misconfiguration is blocking their merge. (2) Helm templates — security contexts are baked into the chart templates (non-root, read-only filesystem, drop ALL capabilities). Developers don't need to remember to add them — they're the default. (3) Kyverno in audit mode — instead of blocking deployments immediately, violations appear in PolicyReports. Teams can review and fix before enforcement mode activates. (4) GitOps delivery — all policies are in Git, so developers can see exactly what's enforced by reading the manifests.

**Result:** Security became a guardrail, not a gate. Developers get fast feedback (CI blocks in minutes, not after deployment). Pod security is the default via Helm templates — no opt-in required. Kyverno's audit mode gives teams time to remediate before enforcement. The GitOps model means security policies are reviewable in PRs like any other code change.

---

### Q12: Tell me about a time you structured infrastructure-as-code for maintainability and reuse.

**Situation:** The Terraform codebase had a security group module that only supported ingress rules. As we needed to scope egress rules across 4 security groups (worker-nodes, cluster, ALB, database), we'd either have to create separate resources for each or extend the module.

**Task:** Extend the existing Terraform module to support egress rules without breaking current usage, and apply scoped egress across all security groups.

**Action:** I extended the security group module by adding a dynamic `egress_rules` variable that mirrors the existing `ingress_rules` pattern. This kept the API consistent — anyone who understood ingress configuration could immediately use egress the same way. I then applied scoped egress rules to all 4 security groups: worker nodes got HTTPS 443 (for ECR/S3/STS) and DNS; the database SG used implicit defaults; ALB and cluster SGs got only the ports they need. The module change was backward-compatible — existing security groups without explicit egress rules continued to work.

**Result:** A single module change enabled egress scoping across 4 security groups. The pattern was intuitive for future engineers because it mirrors the ingress pattern they already know. No 0.0.0.0/0 egress remains on application security groups. The module is reusable for any new security group that needs scoped egress.

---

## 06 - Self-Healing Systems (2 Questions)

### Q13: Describe a system you built that recovers automatically from failures.

**Situation:** The EKS platform runs critical infrastructure services — Flux (GitOps), Istio (service mesh), Kyverno (policy enforcement), EFK (logging). If any of these fail, the blast radius affects the entire cluster: Flux down means no GitOps reconciliation, Istio down means no traffic routing, Kyverno down means no policy enforcement.

**Task:** Design the platform so that component failures self-heal without operator intervention, while security hardening doesn't break the recovery mechanisms.

**Action:** I layered multiple self-healing mechanisms: (1) Flux GitOps reconciliation every 10 minutes — any configuration drift is automatically corrected. If someone manually changes a resource, Flux reverts it. (2) HelmRelease auto-rollback — if a Helm upgrade fails (health checks don't pass), Flux rolls back to the last known-good release. (3) Kubernetes liveness/readiness probes on all workloads — unhealthy pods are automatically restarted. I added `/health` and `/readiness` endpoints to both frontend and backend, and exempted them from rate limiting so probes always succeed. (4) Karpenter node replacement — if a node becomes unhealthy, Karpenter terminates it and launches a replacement. (5) PodDisruptionBudgets — ensure minimum replicas during voluntary disruptions.

**Result:** The system self-heals at every layer: bad config → Flux corrects it; failed upgrade → Helm rolls back; crashed pod → kubelet restarts it; dead node → Karpenter replaces it. During the entire 7-phase hardening process, we never needed manual recovery — every change that broke something was caught by probes and auto-corrected.

---

### Q14: Tell me about a time you designed network isolation that prevents cascading failures.

**Situation:** With all pods able to communicate freely, a single compromised or misbehaving service could cascade to others — a backend bug flooding Elasticsearch with requests, or a rogue pod overwhelming the Flux controllers. There was no blast radius containment.

**Task:** Implement network isolation that contains failures to their namespace and prevents one service from affecting others.

**Action:** I implemented default-deny NetworkPolicies across all 8 namespaces. Each policy starts with `podSelector: {}` (match all pods) and `policyTypes: [Ingress, Egress]` with no rules — effectively blocking everything. Then explicit allow-rules are added for each legitimate communication path. For example, portfolio-api can only receive traffic from portfolio-frontend and istio-ingress — nothing else. Karpenter can only reach AWS APIs and DNS. Flux can reach GitHub and Helm registries. I specifically designed kube-system policies to target pod labels (like `k8s-app: kube-dns`) rather than blanket `podSelector: {}` to avoid over-permitting.

**Result:** Blast radius is now contained per-namespace. A compromised portfolio pod cannot reach Elasticsearch, Flux, or Karpenter. A misbehaving monitoring component cannot flood the application namespace. Each service is isolated to its minimum required communication paths. This is defense-in-depth — even if one layer fails, network isolation prevents cascade.

---

## 07 - Security Posture (3 Questions)

### Q15: Walk me through a comprehensive security audit you conducted on production infrastructure.

**Situation:** The ProjectX EKS platform was running in production with no formal security baseline. We didn't know which CIS controls were passing, which were failing, or where the gaps were. The platform had evolved organically without a security-first approach.

**Task:** Establish a complete security baseline by running industry-standard benchmarks, then systematically remediate all findings across network, pod, application, policy, and IAM layers.

**Action:** I ran kube-bench v0.15.0 against the live EKS cluster using the CIS EKS v1.7.0 benchmark — 46 controls assessed across 3 worker nodes. I classified every finding: 26 PASS, 1 FAIL (cluster-admin overuse), 19 WARN, 5 N/A (AWS-managed). I unified these with 9 application-level concerns from codebase analysis into a single FINDINGS.md, mapping each finding to a specific remediation phase. Then I executed 7 phases over the project: CI/CD security gates (Trivy + Checkov), network isolation (NetworkPolicies + STRICT mTLS across 8 namespaces), pod hardening (non-root, read-only filesystems, drop ALL capabilities), application security (CORS, rate limiting, input validation with 7 automated tests), Kyverno admission control (PSS Restricted), and IAM least-privilege (stripped 3 overprivileged policies, audited all RBAC bindings and IRSA roles).

**Result:** 18 out of 18 security requirements implemented. The single CIS FAIL was remediated. All 14 user-actionable WARNs were addressed. Zero critical or high-severity vulnerabilities remain. The cluster has defense-in-depth: network isolation, pod hardening, application controls, policy enforcement, and least-privilege IAM — all delivered via GitOps and fully auditable.

---

### Q16: Tell me about how you implemented least-privilege IAM across a Kubernetes platform.

**Situation:** Worker nodes had `AmazonEC2FullAccess`, `ElasticLoadBalancingFullAccess`, and `AmazonEC2ContainerRegistryPowerUser` attached — broad AWS managed policies granting far more permissions than needed. Additionally, we had 4 IRSA roles and multiple ClusterRoleBindings that had never been formally audited.

**Task:** Strip all IAM and RBAC permissions to the minimum required and document justification for every remaining binding.

**Action:** For worker node IAM, I removed 3 overprivileged managed policies and replaced them with a custom policy granting only `ec2:DescribeInstances` and `ec2:DescribeTags`. ECR access was downgraded from PowerUser to ReadOnly. For IRSA, I reviewed all 4 custom policies line by line — Karpenter, Velero, AWS LB Controller, and Thanos — checking that every action was scoped to specific resource ARNs. I documented the one exception: Karpenter's `iam:CreateInstanceProfile` requires `Resource: "*"` because instance profile names are dynamically generated. For RBAC, I audited all ClusterRoleBindings — only Flux's `cluster-admin` binding remained (required for GitOps reconciliation), plus a custom scoped CRD role and a read-only SealedSecret role. I documented 3 EKS access entries with justification for each.

**Result:** Worker node permissions reduced from 3 broad policies to 1 custom scoped policy + 2 minimal managed policies. All 4 IRSA roles confirmed well-scoped — zero changes needed. No unnecessary `system:masters` bindings found. Every permission has documented justification. IAM-01, IAM-02, and IAM-03 requirements fully satisfied.

---

### Q17: Describe how you implemented secrets management in a GitOps environment.

**Situation:** In a GitOps workflow, everything lives in Git — including Kubernetes manifests. But secrets can't be stored as plaintext in a repository. We needed a way to manage secrets that's compatible with Flux's Git-based reconciliation while keeping sensitive data encrypted.

**Task:** Ensure all secrets are managed through Sealed Secrets so that no plaintext Secret manifests exist in Git, and the entire secrets lifecycle flows through GitOps.

**Action:** The platform uses Bitnami Sealed Secrets — a controller that decrypts SealedSecret resources into Kubernetes Secrets at runtime. I hardened the sealed-secrets deployment: non-root UID 1001, read-only root filesystem, drop ALL capabilities, NetworkPolicy restricting traffic to only API server and DNS. The RBAC was scoped to a custom `sealed-secrets-reader` ClusterRole — allowing `platform-ops` to inspect SealedSecrets without accessing decrypted values. I added inline security comments to the RBAC manifests documenting why each permission exists. The Sealed Secrets controller itself is deployed via Flux GitOps.

**Result:** Secrets follow the same GitOps workflow as everything else: encrypt locally with `kubeseal`, commit the SealedSecret to Git, Flux applies it, the controller decrypts it in-cluster. No plaintext secrets in the repository. The controller is hardened with defense-in-depth (pod security + network isolation + scoped RBAC). This pattern was established as a project decision: all secrets must be SealedSecrets.

---

## 08 - Disaster Recovery (2 Questions)

### Q18: How did you design your infrastructure to be fully reproducible from Git?

**Situation:** If the EKS cluster was destroyed — whether by accident, attack, or AWS outage — we needed confidence that the entire platform could be rebuilt. But with 10+ platform tools, custom NetworkPolicies, security contexts, IAM roles, and admission policies, manual reconstruction would be error-prone and slow.

**Task:** Ensure the entire infrastructure and platform state is defined in Git so that a complete cluster rebuild is possible from repository contents alone.

**Action:** I implemented infrastructure reproducibility at every layer: (1) Terraform defines all AWS resources — VPC, subnets, security groups, EKS cluster, IAM roles, RDS, S3, ECR, Route53 — in modular workspaces under `terraform-infra/`. (2) Flux CD reconciles all platform tools from `clusters/dev-projectx/` — Istio, Kyverno, EFK, Karpenter, Velero, Sealed Secrets, Thanos, and the portfolio application. (3) Every security hardening change was delivered through Git — NetworkPolicies, PeerAuthentication, ClusterPolicies, security contexts in Helm templates, IAM policies as JSON files in the Terraform tree. (4) CI/CD is defined in GitHub Actions workflows with branch protection managed by Terraform. No manual AWS console changes were made during the entire project.

**Result:** The entire platform is reproducible from two operations: `terraform apply` (creates AWS infrastructure) and Flux bootstrap (deploys everything else). Every security control, network policy, IAM role, and admission policy is in Git. Velero provides backup/restore for stateful data. The project constraint — "all changes via Terraform or GitOps manifests, no manual AWS console changes" — ensures this remains true over time.

---

### Q19: Tell me about your backup and recovery strategy for a Kubernetes platform.

**Situation:** The EKS platform runs stateful services (Elasticsearch for logging, RDS for the database) and critical configuration (Sealed Secrets encryption keys, Flux state). Losing any of these without a recovery path would mean data loss or a broken platform that can't decrypt secrets.

**Task:** Implement backup strategies that cover both stateful data and critical configuration, with automated execution and verified recovery paths.

**Action:** I deployed Velero via Flux with an IRSA role scoped to a specific S3 bucket for backup storage. The IRSA policy allows only the S3 operations and EC2 snapshot actions Velero needs — no excess permissions. Velero backs up Kubernetes resources and persistent volumes on schedule. For the database, RDS automated backups and snapshots are configured via Terraform. The Sealed Secrets controller's encryption key is the most critical secret — without it, existing SealedSecrets can't be decrypted. The key is backed up through Velero's namespace backup of the sealed-secrets namespace. Terraform state is stored in a versioned S3 bucket with a DynamoDB lock table, so infrastructure state is never lost.

**Result:** Recovery paths exist at every layer: Velero restores Kubernetes resources + PVs from S3; RDS restores from automated snapshots; Terraform state restores from versioned S3; Sealed Secrets key restores via Velero. Thanos provides long-term metric storage in S3 so monitoring history survives cluster recreation. All backup tooling is itself managed via GitOps and secured with least-privilege IAM.

---

### Q20: Describe how you ensured configuration drift doesn't silently degrade your disaster recovery posture.

**Situation:** In a complex Kubernetes platform, configuration drift is a silent killer for DR. Someone might manually patch a deployment, modify a NetworkPolicy, or change an IAM role — and now your Git state doesn't match reality. If you rebuild from Git, you get a different system than what was running.

**Task:** Prevent configuration drift so that the Git repository always represents the true desired state of the cluster, making disaster recovery reliable.

**Action:** I enforced three anti-drift mechanisms: (1) Flux CD reconciles every 10 minutes — any manual change to a Flux-managed resource is automatically reverted to match Git. This covers all platform tools, NetworkPolicies, HelmReleases, and application deployments. (2) Kyverno in audit mode continuously scans all running workloads against Pod Security Standards — if a new deployment drifts from the Restricted profile, it appears in PolicyReports immediately. (3) Terraform state is the source of truth for AWS resources — CI/CD runs `terraform plan` on every PR, showing any drift between desired and actual infrastructure state. Branch protection ensures no Terraform changes bypass scanning. (4) The project constraint — no manual AWS console changes — prevents the most common source of IaC drift.

**Result:** Three feedback loops catch drift at different layers: Flux (Kubernetes resources), Kyverno (pod compliance), Terraform (AWS infrastructure). Manual changes are auto-corrected or flagged within minutes. When disaster recovery is needed, the Git state reliably represents what should be running — no surprises from undocumented manual changes.

---

## Quick Reference: Category Coverage

| # | Category | Questions |
|---|----------|-----------|
| 01 | Stable, Fast Infrastructure | Q1, Q2, Q3 |
| 02 | Deployment Automation | Q4, Q5, Q6 |
| 03 | Observability | Q7, Q8 |
| 04 | Auto-Scaling | Q9, Q10 |
| 05 | Developer Efficiency | Q11, Q12 |
| 06 | Self-Healing Systems | Q13, Q14 |
| 07 | Security Posture | Q15, Q16, Q17 |
| 08 | Disaster Recovery | Q18, Q19, Q20 |
