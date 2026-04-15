---
phase: 2
name: Secrets & CI Image Push
status: ready-for-planning
---

# Phase 2: Secrets & CI Image Push — Context

**Gathered:** 2026-04-15
**Mode:** Interactive (autonomous --interactive)

<domain>
## Phase Boundary

1. Gmail SMTP credentials (`SMTP_USER`, `SMTP_PASS`, `RECIPIENT_EMAIL`)
   live encrypted in Git as a Sealed Secret that only the in-cluster
   `sealed-secrets` controller can decrypt.
2. A GitHub Actions workflow builds both `portfolio-web` and
   `portfolio-api` images on every push to `main` that touches
   `app/portfolio/**`, pushes them to the two ECR repos with `:latest`
   and `:<sha>` tags, and surfaces digests in the job summary.
3. Image promotion into the cluster is wired via Flux image automation
   (ImageRepository + ImagePolicy + ImageUpdateAutomation).

Out of scope: chart updates, deploy/cutover (Phase 3), live traffic
verification (Phase 4).

</domain>

<decisions>
## Implementation Decisions (Locked)

### D-01 — Sealed Secret location
- Path: `HelmCharts/portfolio/templates/sealed-secret.yaml`.
- Sealed with cluster controller pubkey (`kubeseal --fetch-cert` from
  the `sealed-secrets` namespace).
- Name: `portfolio-smtp`, namespace: `portfolio` (matches chart values).
- Contains three keys: `SMTP_USER`, `SMTP_PASS`, `RECIPIENT_EMAIL`.
- Rationale: versioned with the chart, reconciled with the rest of the
  app; matches how `platform-tools/*` HelmReleases ship secrets.

### D-02 — ECR repositories
- Two repos: `portfolio-web`, `portfolio-api`, in the existing
  dev account (provisioned by `terraform-infra/root/dev/ecr/`).
- If repos don't already exist in Terraform state, add them to
  `terraform-infra/root/dev/ecr/main.tf` as a preparatory step within
  Phase 2 planning. No manual console creation.
- Immutability: `IMMUTABLE` tag policy for SHA tags; `MUTABLE` allowed
  for `:latest` (or a separate lifecycle rule — planner to decide).

### D-03 — Image tagging
- Every successful build pushes BOTH tags per image:
  - `:<github.sha>` — immutable reference consumed by Flux automation.
  - `:latest` — convenience pointer for humans/debugging.
- Job summary (`$GITHUB_STEP_SUMMARY`) prints both image digests
  (`docker inspect` or buildx metadata output).

### D-04 — Image promotion (Flux image automation)
- Install the image-automation controllers as a new HelmRelease
  (or add to existing flux-system Kustomization) — check
  `clusters/dev-projectx/flux-system/gotk-components.yaml` for current
  components during planning. If absent, add
  `image-reflector-controller` + `image-automation-controller`.
- CRDs per repo:
  - `ImageRepository/portfolio-web`, `ImageRepository/portfolio-api`
    pointing at the two ECR repos (scan interval: 5m).
  - `ImagePolicy` filtering SHA-tagged images only (regex:
    `^[0-9a-f]{40}$`) with `semver` sort disabled — pick newest by
    build timestamp. `:latest` is explicitly excluded from policy
    selection to avoid cyclic updates.
  - `ImageUpdateAutomation` watching the repo, commit strategy:
    direct push to `main` with message
    `chore(images): bump {image} to {tag}` and author
    `fluxcdbot <fluxcdbot@users.noreply.github.com>`.
- Chart `values.yaml` lines are annotated with
  `# {"$imagepolicy": "flux-system:portfolio-web"}` so the automation
  knows which line to rewrite.
- ECR auth for image-reflector: reuse IRSA role pattern already used
  by aws-lb-controller; create an IAM policy granting
  `ecr:DescribeImages`, `ecr:GetAuthorizationToken`, `ecr:BatchGet*`
  on the two repos only.

### D-05 — Workflow file
- New file: `.github/workflows/portfolio-images.yaml`.
- Triggers:
  - `push` to `main` with path filter `app/portfolio/**`
  - `workflow_dispatch` for manual retries.
- Does NOT run on feature branches (image storage cost) — planner
  may add a `pull_request` build-only (no push) job if cheap.
- Concurrency: group `portfolio-images-${{ github.ref }}`, NOT
  cancel-in-progress (avoid partial pushes).
- AWS auth: OIDC via existing `${{ vars.IAM_ROLE }}` — same role as
  Terraform workflow; verify it has `ecr:*` on the two repos during
  planning (add policy if missing).
- Build tool: `docker buildx build --platform linux/amd64`
  (EKS nodes are amd64; matching Karpenter node pool).
- Push: `docker push` both tags; capture digest via
  `docker inspect --format='{{index .RepoDigests 0}}'`.
- Fail-fast: `set -euo pipefail`; any `docker build` non-zero exits
  the job immediately.

### D-06 — Gmail app-password lifecycle
- User generates an App Password at
  https://myaccount.google.com/apppasswords (requires 2FA enabled
  on the Gmail account).
- Documented flow in `HelmCharts/portfolio/README.md`:
  1. Fetch controller cert:
     `kubeseal --controller-namespace sealed-secrets --fetch-cert > pub-cert.pem`
  2. Create plaintext Secret (NEVER committed).
  3. Seal: `kubeseal --cert pub-cert.pem --format yaml < secret.yaml > sealed-secret.yaml`
  4. Commit `sealed-secret.yaml`, discard plaintext.
- Rotation: same process; controller auto-decrypts the new sealed
  secret on reconcile. Old app password revoked in Google UI.

### D-07 — What Phase 2 does NOT change
- No Helm chart values for workloads are edited (Phase 3).
- No chart templates for Deployments, Services, VirtualService
  are added (Phase 3).
- No cutover of live traffic (Phase 3/4).
- The Sealed Secret is committed but mount wiring
  (`envFrom.secretRef`) belongs to Phase 3.

</decisions>

<code_context>
## Existing Code Insights

- Sealed Secrets controller is already installed and reconciled via
  `clusters/dev-projectx/sealed-secrets.yaml` (confirmed — repo has
  `platform-tools/sealed-secrets/` with a working README).
- Existing GitHub Actions OIDC role is referenced as `${{ vars.IAM_ROLE }}`
  in `.github/workflows/deploy-workflow.yaml`; reuse it (verify ECR
  permissions in planning).
- ECR module exists at `terraform-infra/root/dev/ecr/` — inspect during
  planning to confirm repo names and add any missing.
- Flux is installed (gotk-components.yaml present). Image automation
  CRDs may or may not be present — planner to confirm and add if not.
- The current `deploy-workflow.yaml` does Terraform only; do NOT touch it
  beyond optional policy updates for shared IAM role.

</code_context>

<specifics>
## Specific Ideas

- Use `aws-actions/amazon-ecr-login@v2` for docker login; it works
  cleanly with OIDC role assumption.
- buildx cache: `type=gha` (GitHub Actions cache backend) for faster
  incremental builds.
- Print digest line in step summary like:
  `- portfolio-api: 372517046622.dkr.ecr.us-east-1.amazonaws.com/portfolio-api@sha256:xxx`
- ECR lifecycle policy (optional but recommended): keep last 30
  SHA-tagged images, expire untagged after 7 days — add if planner
  sees existing lifecycle pattern in other ECR repos.

</specifics>

<deferred>
## Deferred Ideas

- Image signing (cosign) and SBOM generation — deferred to a later
  hardening pass.
- Multi-arch (arm64) images — nodes are amd64-only today.
- Promoting via PR review instead of direct push — keep direct-push
  for dev; revisit if prod ever needs approval gate.
- Separate staging ECR account — out of scope.
- Dependabot-style base-image update automation — defer.

</deferred>

<canonical_refs>
## Canonical References

- `.planning/ROADMAP.md` — Phase 2 goal + success criteria
- `.planning/REQUIREMENTS.md` — SMS-01..03, SEC-02, CI-01..04
- `platform-tools/sealed-secrets/README.md` — kubeseal workflow
- `clusters/dev-projectx/sealed-secrets.yaml` — controller reconcile
- `clusters/dev-projectx/flux-system/gotk-components.yaml` — flux version
- `terraform-infra/root/dev/ecr/main.tf` — ECR repo definitions
- `.github/workflows/deploy-workflow.yaml` — existing OIDC pattern
- `HelmCharts/portfolio/` — chart location (Phase 3 will extend)

</canonical_refs>
