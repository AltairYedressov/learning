---
phase: 02-secrets-ci-image-push
plan: 02
type: execute
wave: 2
depends_on: ["02-01"]
files_modified:
  - terraform-infra/iam-role-module/Policies/github_actions_ecr_push_policy.json
  - terraform-infra/iam-role-module/Policies/image_reflector_ecr_read_policy.json
  - terraform-infra/root/dev/iam-roles/main.tf
  - terraform-infra/root/dev/iam-roles/variables.tf
autonomous: false
requirements: [CI-02, CI-04]
must_haves:
  truths:
    - "The existing GitHub Actions OIDC role can push images to portfolio-web and portfolio-api only"
    - "A new IRSA role 'image-reflector-role' can describe and pull image metadata from those two repos"
    - "Neither policy grants access to other ECR repos in the account"
  artifacts:
    - path: "terraform-infra/iam-role-module/Policies/github_actions_ecr_push_policy.json"
      provides: "ECR push permissions scoped to the two portfolio repos"
      contains: "ecr:PutImage"
    - path: "terraform-infra/iam-role-module/Policies/image_reflector_ecr_read_policy.json"
      provides: "ECR read-only permissions for Flux image-reflector"
      contains: "ecr:DescribeImages"
    - path: "terraform-infra/root/dev/iam-roles/main.tf"
      provides: "image_reflector_irsa_role module block"
      contains: "image_reflector_irsa_role"
  key_links:
    - from: "github_actions_ecr_push_policy.json"
      to: "existing GitHub Actions OIDC role (vars.IAM_ROLE)"
      via: "checkpoint:human-action attaches policy in AWS console / CLI"
      pattern: "aws iam attach-role-policy"
    - from: "image_reflector_irsa_role"
      to: "serviceaccount:flux-system:image-reflector-controller"
      via: "IRSA trust policy StringEquals on sub"
      pattern: "system:serviceaccount:flux-system:image-reflector-controller"
---

<objective>
Grant the CI workflow the ability to push to the new ECR repos, and create the IRSA role that Flux image-reflector-controller will assume to read image tags.

Purpose: Plan 03 (CI workflow) needs push perms on the GitHub Actions OIDC role; Plan 04 (Flux image automation) needs a pod-level IRSA role with ECR read.
Output: Two IAM policy JSON files + one new IRSA role module in Terraform, plus a checkpoint confirming the existing GitHub Actions role has the push policy attached.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/02-secrets-ci-image-push/02-CONTEXT.md
@terraform-infra/root/dev/iam-roles/main.tf
@terraform-infra/root/dev/iam-roles/variables.tf
@terraform-infra/root/dev/iam-roles/data-blocks.tf
@terraform-infra/iam-role-module/main.tf
@.github/workflows/deploy-workflow.yaml

<interfaces>
iam-role-module signature (terraform-infra/iam-role-module/):
  - inputs: role_name, environment, principal_type, principal_identifiers,
    assume_role_action (default sts:AssumeRole), assume_role_conditions (map),
    aws_managed_policy_arns (list), custom_policy_json_path (string)
  - The existing aws_lb_controller_irsa_role and karpenter_irsa_role blocks
    in main.tf are the canonical IRSA pattern to copy.

EKS OIDC provider data source (already present):
  data.aws_iam_openid_connect_provider.eks_oidc_provider

Existing GitHub Actions OIDC role:
  Referenced only as ${{ vars.IAM_ROLE }} in deploy-workflow.yaml.
  Not defined in this Terraform state — bootstrapped manually.
  Account ID: 372517046622, region us-east-1.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Author ECR push policy JSON (scoped to portfolio-web + portfolio-api) — CI-02</name>
  <files>terraform-infra/iam-role-module/Policies/github_actions_ecr_push_policy.json</files>
  <action>
Create a new IAM policy document with two statements:

1. Statement "ECRAuth" — Allow `ecr:GetAuthorizationToken` on `*` (required; the action does not support resource-level constraints).
2. Statement "ECRPush" — Allow the following actions:
   - ecr:BatchCheckLayerAvailability
   - ecr:BatchGetImage
   - ecr:CompleteLayerUpload
   - ecr:DescribeImages
   - ecr:DescribeRepositories
   - ecr:GetDownloadUrlForLayer
   - ecr:InitiateLayerUpload
   - ecr:PutImage
   - ecr:UploadLayerPart
   Resource: [
     "arn:aws:ecr:us-east-1:372517046622:repository/portfolio-web",
     "arn:aws:ecr:us-east-1:372517046622:repository/portfolio-api"
   ]

Version "2012-10-17". No wildcards on repo names. File is intentionally static JSON (no Terraform interpolation) so it lives alongside the other policy files in `iam-role-module/Policies/`.
  </action>
  <verify>
    <automated>python3 -c "import json; d=json.load(open('terraform-infra/iam-role-module/Policies/github_actions_ecr_push_policy.json')); assert any('portfolio-web' in str(s['Resource']) for s in d['Statement']), 'portfolio-web not found'; assert any('portfolio-api' in str(s['Resource']) for s in d['Statement']), 'portfolio-api not found'; assert any('ecr:PutImage' in s['Action'] for s in d['Statement'] if isinstance(s['Action'], list))"</automated>
  </verify>
  <done>Valid JSON policy document; `aws iam validate-policy` style lint passes (jq + basic structural check).</done>
</task>

<task type="auto">
  <name>Task 2: Author image-reflector read-only policy + add IRSA role module (CI-04, D-04)</name>
  <files>terraform-infra/iam-role-module/Policies/image_reflector_ecr_read_policy.json, terraform-infra/root/dev/iam-roles/main.tf, terraform-infra/root/dev/iam-roles/variables.tf</files>
  <action>
Part A — Policy JSON (`image_reflector_ecr_read_policy.json`):

Two statements:
1. "ECRAuth" — Allow `ecr:GetAuthorizationToken` on `*`.
2. "ECRRead" — Allow:
   - ecr:BatchCheckLayerAvailability
   - ecr:BatchGetImage
   - ecr:DescribeImages
   - ecr:DescribeRepositories
   - ecr:GetDownloadUrlForLayer
   - ecr:ListImages
   Resource: the two portfolio repo ARNs (same as Task 1, scoped list).

Part B — Variable (`variables.tf`):
Add `variable "image_reflector_irsa_role" { type = string; default = "image-reflector-role" }` matching the naming style of the other IRSA role variables.

Part C — IRSA module block (`main.tf`): Append after `aws_lb_controller_irsa_role` module. Copy its structure exactly. Key fields:

  module "image_reflector_irsa_role" {
    source                = "../../../iam-role-module"
    role_name             = var.image_reflector_irsa_role
    environment           = var.environment
    assume_role_action    = "sts:AssumeRoleWithWebIdentity"
    principal_type        = "Federated"
    principal_identifiers = [data.aws_iam_openid_connect_provider.eks_oidc_provider.arn]
    assume_role_conditions = {
      sub = {
        test     = "StringEquals"
        variable = "${replace(data.aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:sub"
        values   = ["system:serviceaccount:flux-system:image-reflector-controller"]
      }
      aud = {
        test     = "StringEquals"
        variable = "${replace(data.aws_iam_openid_connect_provider.eks_oidc_provider.url, "https://", "")}:aud"
        values   = ["sts.amazonaws.com"]
      }
    }
    custom_policy_json_path = "${path.module}/../../../iam-role-module/Policies/image_reflector_ecr_read_policy.json"
    aws_managed_policy_arns = []
  }

Run `terraform fmt` in `terraform-infra/root/dev/iam-roles/`. Do not touch other modules.

Rationale (per D-04): reuse IRSA pattern already used by aws-lb-controller; policy is read-only and scoped to the two portfolio repos only — `ecr:BatchGet*` and `ecr:DescribeImages` per CONTEXT.
  </action>
  <verify>
    <automated>cd terraform-infra/root/dev/iam-roles && terraform fmt -check && terraform init -backend=false -input=false >/dev/null && terraform validate</automated>
  </verify>
  <done>
`terraform validate` passes. `terraform plan` (in CI) will show one new IAM role (`image-reflector-role-dev`) with the read-only policy attached. Output ARN available for Plan 04 annotation.
  </done>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <name>Task 3: Attach ECR push policy to the existing GitHub Actions OIDC role</name>
  <what-built>
A new IAM policy JSON exists at `terraform-infra/iam-role-module/Policies/github_actions_ecr_push_policy.json` scoping ECR push to portfolio-web/portfolio-api. The existing GitHub Actions OIDC role (referenced as `${{ vars.IAM_ROLE }}` in `deploy-workflow.yaml`) is NOT managed by this Terraform — it was bootstrapped manually. Claude cannot assume the admin role needed to mutate it non-interactively.
  </what-built>
  <how-to-verify>
1. Look up the role name in GitHub repo Settings → Secrets and variables → Actions → Variables → `IAM_ROLE`.
2. Run locally (with admin AWS credentials):
     ROLE_NAME=<the value of vars.IAM_ROLE, trimmed to just the role name after the last slash>
     aws iam create-policy \
       --policy-name GitHubActionsPortfolioECRPush \
       --policy-document file://terraform-infra/iam-role-module/Policies/github_actions_ecr_push_policy.json
     POLICY_ARN=<ARN printed above>
     aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"
3. Confirm attachment:
     aws iam list-attached-role-policies --role-name "$ROLE_NAME" | grep GitHubActionsPortfolioECRPush
4. (Optional smoke test on a throwaway branch): run `aws ecr get-login-password` through a workflow dispatch to confirm auth works before Plan 03 executes.
  </how-to-verify>
  <resume-signal>Reply "attached" with the policy ARN, or describe errors.</resume-signal>
</task>

</tasks>

<verification>
- `terraform validate` passes in `terraform-infra/root/dev/iam-roles/`.
- `image-reflector-role-dev` ARN retrievable post-apply via:
    aws iam get-role --role-name image-reflector-role-dev
- GitHub Actions role has `GitHubActionsPortfolioECRPush` policy attached (confirmed by human checkpoint).
</verification>

<success_criteria>
CI role can push, image-reflector IRSA role exists and can read, both scoped to only portfolio-web/portfolio-api. Maps to ROADMAP success criterion #5 and REQ CI-02, CI-04.
</success_criteria>

<output>
After completion, create `.planning/phases/02-secrets-ci-image-push/02-02-SUMMARY.md`. Record the `image-reflector-role-dev` ARN for Plan 04 to consume.
</output>
