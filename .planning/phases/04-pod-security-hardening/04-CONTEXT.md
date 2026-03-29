# Phase 4: Pod Security Hardening - Context

**Gathered:** 2026-03-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Every workload pod runs with minimal OS-level privileges — runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities, no privileged mode. Covers portfolio app pods (frontend + backend) and EFK security context gaps. All workloads must pass health checks after changes.

</domain>

<decisions>
## Implementation Decisions

### Dockerfile Non-Root Users
- **D-01:** Add non-root user in BOTH Dockerfiles AND Kubernetes security contexts (defense in depth — images can't run as root even outside K8s)
- **D-02:** Both frontend and backend use the same UID/GID 1001 (consistent with sealed-secrets pattern, no shared volumes between services)
- **D-03:** Frontend (node:20-alpine): `addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -D appuser`, then `USER appuser`
- **D-04:** Backend (python:3.12-slim): `groupadd -g 1001 appgroup && useradd -u 1001 -g appgroup appuser`, then `USER appuser`

### Writable Paths Strategy
- **D-05:** readOnlyRootFilesystem: true on all containers, with emptyDir mounted at /tmp only (minimal attack surface)
- **D-06:** If runtime errors surface from other writable paths (e.g., __pycache__, .npm), add targeted emptyDir mounts — but start minimal

### Pod Security Contexts (Helm Chart)
- **D-07:** Pod-level: runAsNonRoot: true, runAsUser: 1001, runAsGroup: 1001, fsGroup: 1001, seccompProfile: RuntimeDefault
- **D-08:** Container-level: allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: drop: [ALL]
- **D-09:** Pattern matches sealed-secrets HelmRelease (the reference implementation in this cluster)

### Platform Tool Coverage
- **D-10:** Scope: portfolio frontend + backend (zero security contexts today) AND EFK gaps (Kibana + Elasticsearch missing runAsNonRoot, readOnlyRootFilesystem)
- **D-11:** Sealed-secrets already fully hardened — skip
- **D-12:** Other platform tools (Karpenter, Velero, Thanos, AWS LB Controller) are upstream Helm charts with their own defaults — out of scope for this phase

### Rollout & Verification
- **D-13:** All changes deployed at once (small cluster, few workloads — incremental adds complexity without real risk reduction)
- **D-14:** Verification checklist: pods in Running state, health endpoints responding, no permission-denied errors in logs

### Claude's Discretion
- Exact Dockerfile commands for file ownership (COPY --chown, RUN chown) to ensure non-root user can read app files
- Whether EFK Fluent Bit needs security context changes (it's a DaemonSet with host log access)
- Specific seccompProfile type for EFK pods (RuntimeDefault or Unconfined if needed)
- Whether to add sizeLimit to emptyDir volumes

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Reference Security Context Pattern
- `platform-tools/sealed-secrets/base/helmrelease.yaml` lines 111-127 — Complete pod + container security context pattern (runAsNonRoot, readOnlyRootFilesystem, drop ALL, seccompProfile)

### Portfolio Helm Templates (modify these)
- `HelmCharts/portfolio/templates/01-backend.yaml` — Backend deployment, NO security contexts today
- `HelmCharts/portfolio/templates/02-frontend.yaml` — Frontend deployment, NO security contexts today

### Dockerfiles (modify these)
- `app/backend/Dockerfile` — Python 3.12-slim, runs as root, no USER directive
- `app/frontend/Dockerfile` — Node 20 Alpine, runs as root, no USER directive

### EFK HelmReleases (fix gaps)
- `platform-tools/efk-logging/base/helmrelease-kibana.yaml` lines 54-62 — Has partial security context (missing runAsNonRoot, readOnlyRootFilesystem)
- `platform-tools/efk-logging/base/helmrelease-elasticsearch.yaml` lines 78-86 — Has partial security context (missing runAsNonRoot, readOnlyRootFilesystem)

### Requirements
- `.planning/REQUIREMENTS.md` — EKS-03: All pods have security contexts (runAsNonRoot, readOnlyRootFilesystem, drop ALL capabilities)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Sealed-secrets HelmRelease: Complete security context pattern with podSecurityContext + containerSecurityContext — direct template for portfolio pods
- Flux gotk-components: All Flux controllers already have full security contexts (runAsNonRoot, readOnlyRootFilesystem, drop ALL) — no changes needed

### Established Patterns
- Pod security contexts set via Helm values (podSecurityContext / containerSecurityContext keys)
- UID 1001 used consistently (sealed-secrets)
- seccompProfile: RuntimeDefault used as standard
- EFK uses UID 1000 (upstream default) — keep as-is, just fill missing fields

### Integration Points
- Helm chart templates need securityContext blocks added to pod spec and container spec
- Dockerfiles need non-root user created before COPY/CMD
- File ownership in Dockerfiles must ensure non-root user can read /app directory
- EFK HelmRelease values need additional security context fields

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches following the sealed-secrets reference pattern.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-pod-security-hardening*
*Context gathered: 2026-03-29*
