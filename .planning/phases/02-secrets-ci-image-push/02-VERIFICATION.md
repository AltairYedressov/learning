---
phase: 02
status: human_needed
verified: 2026-04-15
---

# Phase 2 Verification

## Status: human_needed

All in-repo artifacts are committed and pass every check available in this sandbox
(`terraform validate`, `kubectl kustomize`, JSON parse, structural workflow checks).
Cluster-side and AWS-side verification require credentials that are not available
here — see **Human Actions** below.

## Automated Checks (performed)

| Check                                                                                       | Result                                                            |
| ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `terraform validate` in `terraform-infra/root/dev/ecr/`                                     | PASS                                                              |
| `terraform validate` in `terraform-infra/root/dev/iam-roles/`                               | PASS                                                              |
| `terraform fmt -recursive` on touched dirs                                                  | CLEAN                                                             |
| `python3 -c "import json; json.load(...)"` on both new IAM policy files                     | PASS                                                              |
| `kubectl kustomize portfolio/image-automation/base`                                          | RENDERS 5 resources                                               |
| `kubectl kustomize clusters/dev-projectx/flux-system`                                        | RENDERS (incl. new SA with IRSA annotation)                       |
| Workflow YAML structural check (regex for key lines + paths + concurrency)                  | PASS                                                              |
| `git log --oneline` contains 5 `feat(02):` commits                                          | PASS                                                              |

## Human Actions Required

1. **Attach GitHub Actions ECR push policy (Plan 02-02 Task 3).**
   ```
   aws iam create-policy \
     --policy-name GitHubActionsPortfolioECRPush \
     --policy-document file://terraform-infra/iam-role-module/Policies/github_actions_ecr_push_policy.json
   aws iam attach-role-policy --role-name <IAM_ROLE name from GitHub vars> --policy-arn <printed ARN>
   ```
2. **Apply Terraform (deploy-workflow on merge to main)** — provisions the two new ECR repos, the `image-reflector-role-dev` IRSA role, and the lifecycle policies.
3. **Replace SealedSecret placeholder (Plan 02-05 Task 3).** Follow the README section "SMTP Sealed Secret (portfolio-smtp)" to run `kubeseal` against the cluster controller and commit the ciphertext.
4. **Trigger and observe the `portfolio-images` workflow (Plan 02-03 Task 2).** Confirm both matrix jobs succeed, digests surface in the run summary, and `aws ecr list-images` shows `:latest` + `:<sha>` tags for both repos.
5. **Verify Flux image automation after reconcile (~10m post-merge):**
   - `flux get image repository -n flux-system` → both `portfolio-web` / `portfolio-api` Ready with recent scan.
   - `flux get image policy -n flux-system` → both show `Latest image` populated.
   - `flux get image update -n flux-system` → `portfolio` Ready.
   - `kubectl -n flux-system logs deploy/image-reflector-controller` → no ECR/STS auth errors.

## Deferred Concerns

### ImagePolicy tie-breaker is not build-time ordered (planner-flagged)

Per Plan 02-04 Task 2, `ImagePolicy` uses `alphabetical: asc` with SHA-only filter
(`^[0-9a-f]{40}$`). With random hex SHA tags this is deterministic but **does not
guarantee the newest-built image wins** — it picks the lexicographically highest SHA.
In practice that means rollback or sporadic non-promotion of newer builds.

Recommended follow-up (NOT implemented here, out of scope for Phase 2):
- Option A: extend Plan 02-03 workflow to also tag with `YYYYMMDDTHHMMSS-<sha>` and
  change ImagePolicy filter to that prefix.
- Option B: use `numerical: { order: asc }` with an epoch build number tag.

This is tracked as a Phase 2 deferred item per user instruction; planner explicitly
locked the current regex and "semver disabled" behavior.

### image-reflector/image-automation controller Deployments

`gotk-components.yaml` references these controllers in RBAC but the SA and
Deployment resources were not present. We added the ServiceAccount with the IRSA
annotation in `clusters/dev-projectx/flux-system/image-automation-sa.yaml`. The
Deployment itself must still be installed — either:
- Run `flux install --components-extra=image-reflector-controller,image-automation-controller`
  locally and commit the resulting Deployment/Service blocks back into
  `gotk-components.yaml`; or
- Bootstrap re-run with the extra components flag.

Flux reconcile will error with "deployment not found" until one of the above is done.
This is called out here because the sandbox has no `flux` CLI to regenerate the
components file.

### `helm template` on chart fails (pre-existing, not Phase 2)

`HelmCharts/portfolio/templates/02-frontend.yaml` dereferences `.Values.replicas.frontend`
without a fallback, and no `values.yaml` ships with the chart yet. Phase 3 adds
`values.yaml`. The SealedSecret template we added is syntactically valid and renders
independently.

## Checkpoints Returned

The following plans had `checkpoint:human-action` / `checkpoint:human-verify` tasks
that could not be executed autonomously; they are captured in the Human Actions
section above:
- 02-02 Task 3 (IAM policy attach)
- 02-03 Task 2 (workflow verification)
- 02-05 Task 3 (kubeseal sealing)
