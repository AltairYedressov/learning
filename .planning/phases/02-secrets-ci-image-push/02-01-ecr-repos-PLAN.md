---
phase: 02-secrets-ci-image-push
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - terraform-infra/root/dev/ecr/terraform.tfvars
  - terraform-infra/ecr/maint.tf
autonomous: true
requirements: [CI-02]
must_haves:
  truths:
    - "ECR repo portfolio-web exists in dev account with IMMUTABLE SHA tags allowed"
    - "ECR repo portfolio-api exists in dev account with IMMUTABLE SHA tags allowed"
    - "Lifecycle policy caps SHA-tagged images at last 30 and expires untagged after 7 days"
  artifacts:
    - path: "terraform-infra/root/dev/ecr/terraform.tfvars"
      provides: "Declares portfolio-web and portfolio-api in ecr_names"
      contains: "portfolio-web"
    - path: "terraform-infra/ecr/maint.tf"
      provides: "ECR module with lifecycle policy resource"
      contains: "aws_ecr_lifecycle_policy"
  key_links:
    - from: "terraform-infra/root/dev/ecr/terraform.tfvars"
      to: "aws_ecr_repository.default"
      via: "ecr_names variable"
      pattern: "portfolio-web|portfolio-api"
---

<objective>
Create the two ECR repositories (`portfolio-web`, `portfolio-api`) that CI will push to and that Flux image-automation will scan.

Purpose: Without these repos, the CI workflow cannot push images and Flux cannot reconcile image tags.
Output: Terraform changes applied; two new ECR repos in `us-east-1`, dev account.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/02-secrets-ci-image-push/02-CONTEXT.md
@terraform-infra/root/dev/ecr/terraform.tfvars
@terraform-infra/root/dev/ecr/main.tf
@terraform-infra/ecr/maint.tf
@terraform-infra/ecr/variables.tf

<interfaces>
Existing ECR module signature (terraform-infra/ecr/maint.tf):
- resource aws_ecr_repository.default, for_each over var.ecr_names
- variables: environment, ecr_names (list), image_tag_mutability, scan_on_push

Existing tfvars (terraform-infra/root/dev/ecr/terraform.tfvars):
ecr_names = ["helm-charts/portfolio", "images/portfolio-frontend", "images/portfolio-backend"]
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add portfolio-web and portfolio-api to ecr_names (D-02)</name>
  <files>terraform-infra/root/dev/ecr/terraform.tfvars</files>
  <action>
Append "portfolio-web" and "portfolio-api" to the existing ecr_names list per D-02. Keep pre-existing entries (`helm-charts/portfolio`, `images/portfolio-frontend`, `images/portfolio-backend`) untouched — they may still be referenced by other tooling and Phase 2 does not own their removal. Do NOT change image_tag_mutability at the tfvars level; per-repo immutability comes from the module change in Task 2.

Final list:
ecr_names = [
  "helm-charts/portfolio",
  "images/portfolio-frontend",
  "images/portfolio-backend",
  "portfolio-web",
  "portfolio-api",
]
  </action>
  <verify>
    <automated>grep -q "portfolio-web" terraform-infra/root/dev/ecr/terraform.tfvars && grep -q "portfolio-api" terraform-infra/root/dev/ecr/terraform.tfvars</automated>
  </verify>
  <done>Both repo names present in tfvars; `terraform fmt -check` passes in terraform-infra/root/dev/ecr/.</done>
</task>

<task type="auto">
  <name>Task 2: Extend ECR module with IMMUTABLE override + lifecycle policy (D-02, specifics)</name>
  <files>terraform-infra/ecr/maint.tf, terraform-infra/ecr/variables.tf</files>
  <action>
Extend the module so the two new repos get IMMUTABLE tag mutability and a lifecycle policy (keep last 30 SHA-tagged images, expire untagged after 7 days), while leaving existing repos on their current MUTABLE setting to avoid blast radius.

1. Add a new variable `immutable_repos` (list(string), default []) to `terraform-infra/ecr/variables.tf`. Description: "Subset of ecr_names that should be IMMUTABLE regardless of image_tag_mutability default."
2. In `terraform-infra/ecr/maint.tf`, change the `image_tag_mutability` line on `aws_ecr_repository.default` to:
   `image_tag_mutability = contains(var.immutable_repos, each.value) ? "IMMUTABLE" : var.image_tag_mutability`
3. Add `resource "aws_ecr_lifecycle_policy" "default"` with `for_each = toset(var.immutable_repos)`, `repository = aws_ecr_repository.default[each.value].name`, and a policy JSON that:
   - Rule 1 (priority 1): keep last 30 images with `tagStatus=tagged`, `tagPatternList=["*"]`, action expire.
   - Rule 2 (priority 2): expire `tagStatus=untagged` after 7 days (`countType=sinceImagePushed`, `countUnit=days`, `countNumber=7`), action expire.
4. In `terraform-infra/root/dev/ecr/main.tf`, pass `immutable_repos = ["portfolio-web", "portfolio-api"]` into the module call (requires adding the argument).
5. Run `terraform fmt` inside `terraform-infra/root/dev/ecr/` and `terraform-infra/ecr/`.

Do NOT touch provider blocks, backend config, or the other existing module arguments. Avoid using `aws_ecr_lifecycle_policy` on the legacy `helm-charts/portfolio`, `images/*` repos (not in immutable_repos → for_each skips them).
  </action>
  <verify>
    <automated>cd terraform-infra/root/dev/ecr && terraform fmt -check -recursive ../../../ecr && terraform init -backend=false -input=false >/dev/null && terraform validate</automated>
  </verify>
  <done>
`terraform validate` passes. Diff shows two new `aws_ecr_repository.default` entries (`portfolio-web`, `portfolio-api`) with IMMUTABLE and two new `aws_ecr_lifecycle_policy` resources. Apply happens via the existing Terraform workflow on merge to main.
  </done>
</task>

</tasks>

<verification>
- `terraform plan` (run via existing deploy-workflow.yaml) shows 2 new ECR repos + 2 new lifecycle policies, zero destroys on existing repos.
- After apply, `aws ecr describe-repositories --repository-names portfolio-web portfolio-api` returns both.
- `aws ecr get-lifecycle-policy --repository-name portfolio-web` returns the 30-image + 7-day-untagged policy.
</verification>

<success_criteria>
Two ECR repos exist and enforce IMMUTABLE SHA tags with lifecycle trimming; Phase 2 CI workflow (Plan 03) can push to them. Maps to ROADMAP Phase 2 success criterion #3 and REQ CI-02.
</success_criteria>

<output>
After completion, create `.planning/phases/02-secrets-ci-image-push/02-01-SUMMARY.md`.
</output>
