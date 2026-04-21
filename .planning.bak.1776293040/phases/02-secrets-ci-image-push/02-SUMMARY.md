---
phase: 02
name: Secrets & CI Image Push
status: executed
completed: 2026-04-15
plans_executed: 5
plans_total: 5
requirements: [SMS-01, SMS-02, SMS-03, SEC-02, CI-01, CI-02, CI-03, CI-04]
---

# Phase 2: Secrets & CI Image Push — Summary

One-liner: Portfolio images get a secure ECR push pipeline (GitHub OIDC → scoped IAM → Flux image automation with IRSA), and Gmail SMTP creds are checked in as a SealedSecret template for in-cluster decryption.

## Plans Executed

| Plan  | Title                              | Commit    | Key artifacts                                                                                 |
| ----- | ---------------------------------- | --------- | --------------------------------------------------------------------------------------------- |
| 02-01 | ECR repos (portfolio-web, api)     | `d6f5339` | `terraform-infra/ecr/{maint,variables}.tf`, `terraform-infra/root/dev/ecr/{main.tf,tfvars}`   |
| 02-05 | Sealed Secret template + docs      | `7596bc5` | `HelmCharts/portfolio/templates/sealed-secret.yaml`, `HelmCharts/portfolio/README.md`         |
| 02-02 | IAM policies + image-reflector IRSA | `84ee2f2` | `iam-role-module/Policies/{github_actions_ecr_push,image_reflector_ecr_read}_policy.json`, `root/dev/iam-roles/{main,variables}.tf` |
| 02-03 | GitHub Actions workflow            | `83d234d` | `.github/workflows/portfolio-images.yaml`                                                     |
| 02-04 | Flux image automation              | `5f402be` | `portfolio/image-automation/base/*.yaml`, `clusters/dev-projectx/portfolio-image-automation.yaml`, `flux-system/image-automation-sa.yaml` |

## Decisions Honored (from 02-CONTEXT.md)

- D-01: SealedSecret at `HelmCharts/portfolio/templates/sealed-secret.yaml`, name/namespace `portfolio-smtp/portfolio`, three keys.
- D-02: Two new ECR repos with IMMUTABLE tag mutability via new `immutable_repos` variable; keep-30 / expire-untagged-7d lifecycle policy attached only to those repos. Legacy repos untouched.
- D-03: Workflow pushes both `:latest` and `:<sha>`; digests written to `$GITHUB_STEP_SUMMARY`.
- D-04: ImageRepository (interval 5m, `provider: aws`), ImagePolicy (regex `^[0-9a-f]{40}$`, alphabetical asc), ImageUpdateAutomation (direct push to main, fluxcdbot author, `chore(images)` message).
- D-05: Workflow path-filtered to `app/portfolio/**`, PRs build-only, concurrency non-cancel, OIDC via `${{ vars.IAM_ROLE }}`, buildx + GHA cache, amd64 only.
- D-06: Rotation + seal flow documented in chart README.
- D-07: No workload Deployment/values.yaml changes; `envFrom` wiring deferred to Phase 3.

## Deviations

- **[Rule 3 — Missing infrastructure]** `gotk-components.yaml` referenced `image-reflector-controller` / `image-automation-controller` ServiceAccounts in RBAC but did not actually define them. Added explicit `clusters/dev-projectx/flux-system/image-automation-sa.yaml` that defines both SAs and carries the IRSA annotation. Registered it in the flux-system kustomization.
- **ImagePolicy tie-breaker** — Per the planner note, `alphabetical: asc` with SHA-only filter provides deterministic selection but does NOT guarantee newest-built image wins. Flagged in VERIFICATION.md (deferred_concerns); a follow-up plan should add a time-prefix tag or switch to `numerical` on a Unix-epoch build tag. Implemented as planned; not redesigned.

## Human Checkpoints (from plans)

1. **02-02 Task 3** — Attach `GitHubActionsPortfolioECRPush` policy to the existing GitHub Actions OIDC role (`vars.IAM_ROLE`). Requires admin AWS creds.
2. **02-03 Task 2** — Merge to main, watch workflow run, confirm both digests appear in the job summary and ECR contains both tagged images.
3. **02-05 Task 3** — Run `kubeseal` locally with Gmail app password to replace `__REPLACE_VIA_KUBESEAL__` placeholders and commit the ciphertext.

## Environment Caveats

- `terraform apply`, `kubectl`, `kubeseal`, `aws` and cluster reconciliation were intentionally not executed from this sandbox. Every artifact is a checked-in file validated locally with `terraform validate` and `kubectl kustomize` where possible.
- `actionlint` and `yamllint` were unavailable; workflow validated with structural regex checks.
- `helm template HelmCharts/portfolio` fails on pre-existing nil-value references unrelated to Phase 2 (Phase 3 will add `values.yaml`). SealedSecret template is syntactically valid.

## Key Files

Created:
- `terraform-infra/iam-role-module/Policies/github_actions_ecr_push_policy.json`
- `terraform-infra/iam-role-module/Policies/image_reflector_ecr_read_policy.json`
- `HelmCharts/portfolio/templates/sealed-secret.yaml`
- `.github/workflows/portfolio-images.yaml`
- `portfolio/image-automation/base/{image-repository-web,image-repository-api,image-policy-web,image-policy-api,image-update-automation,kustomization}.yaml`
- `clusters/dev-projectx/portfolio-image-automation.yaml`
- `clusters/dev-projectx/flux-system/image-automation-sa.yaml`

Modified:
- `terraform-infra/ecr/{maint,variables}.tf`
- `terraform-infra/root/dev/ecr/{main.tf,terraform.tfvars}`
- `terraform-infra/root/dev/iam-roles/{main,variables}.tf`
- `HelmCharts/portfolio/README.md`
- `clusters/dev-projectx/flux-system/kustomization.yaml`

## Self-Check: PASSED
All five plans have commits in `git log`, all referenced files exist on disk, `terraform validate` passes in both affected root workspaces, `kubectl kustomize` renders `portfolio/image-automation/base` and `clusters/dev-projectx/flux-system` successfully.
