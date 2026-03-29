# Phase 4: Pod Security Hardening - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-29
**Phase:** 04-pod-security-hardening
**Areas discussed:** Dockerfile USER changes, Writable paths strategy, Platform tool coverage, Rollout approach

---

## Dockerfile USER Changes

| Option | Description | Selected |
|--------|-------------|----------|
| Dockerfile + K8s both | Add USER directive in Dockerfiles AND set runAsUser/runAsNonRoot in K8s security contexts. Defense in depth. | ✓ |
| K8s security context only | Don't modify Dockerfiles — only add security contexts in Helm chart. | |
| You decide | Claude picks best approach. | |

**User's choice:** Dockerfile + K8s both (Recommended)
**Notes:** Defense in depth — images can't run as root even outside K8s.

---

### Follow-up: UID Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Same UID 1001 for both | Consistent with sealed-secrets pattern. Simpler to manage. | ✓ |
| Different UIDs per service | Frontend=1001, Backend=1002. Stronger isolation. | |
| You decide | Claude picks based on existing patterns. | |

**User's choice:** Same UID 1001 for both (Recommended)
**Notes:** No shared volumes between services, consistency preferred.

---

## Writable Paths Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| emptyDir for /tmp only | Mount emptyDir at /tmp for both services. Minimal attack surface. | ✓ |
| emptyDir for /tmp + app-specific dirs | Mount /tmp plus __pycache__, .npm, etc. More permissive. | |
| You decide | Claude analyzes app code for exact writable paths. | |

**User's choice:** emptyDir for /tmp only (Recommended)
**Notes:** Start minimal, add targeted mounts only if runtime errors surface.

---

## Platform Tool Coverage

| Option | Description | Selected |
|--------|-------------|----------|
| Portfolio + fix EFK gaps | Harden portfolio pods and fill EFK gaps (missing runAsNonRoot, readOnlyRootFilesystem). | ✓ |
| Portfolio only | Only harden portfolio app pods. Leave platform tools as-is. | |
| All workloads | Audit and harden every pod including Karpenter, Velero, Thanos. | |
| You decide | Claude determines which workloads need hardening. | |

**User's choice:** Portfolio + fix EFK gaps (Recommended)
**Notes:** Sealed-secrets already done. Other platform tools are upstream Helm charts with their own defaults.

---

## Rollout Approach

| Option | Description | Selected |
|--------|-------------|----------|
| All at once, verify after | Apply all security contexts in one commit. Verify via health checks and logs. | ✓ |
| Incremental by workload | Harden one workload at a time with separate commits. | |
| You decide | Claude picks rollout strategy. | |

**User's choice:** All at once, verify after (Recommended)
**Notes:** Small cluster with few workloads — incremental adds complexity without real risk reduction.

---

## Claude's Discretion

- Exact Dockerfile commands for file ownership (COPY --chown, RUN chown)
- Whether EFK Fluent Bit needs security context changes
- Specific seccompProfile type for EFK pods
- Whether to add sizeLimit to emptyDir volumes

## Deferred Ideas

None — discussion stayed within phase scope.
