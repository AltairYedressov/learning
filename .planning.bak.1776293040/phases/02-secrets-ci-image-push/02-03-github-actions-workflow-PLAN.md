---
phase: 02-secrets-ci-image-push
plan: 03
type: execute
wave: 3
depends_on: ["02-01", "02-02"]
files_modified:
  - .github/workflows/portfolio-images.yaml
autonomous: false
requirements: [CI-01, CI-02, CI-03]
must_haves:
  truths:
    - "A push to main touching app/portfolio/** builds both images and pushes :latest + :<sha> to ECR"
    - "Feature branches and PRs do NOT push (build-only)"
    - "Job fails fast on docker build errors and prints both image digests in the step summary"
    - "Workflow uses OIDC via vars.IAM_ROLE — no long-lived AWS credentials"
  artifacts:
    - path: ".github/workflows/portfolio-images.yaml"
      provides: "GitHub Actions workflow that builds and pushes both images"
      min_lines: 80
      contains: "portfolio-web"
  key_links:
    - from: ".github/workflows/portfolio-images.yaml"
      to: "aws-actions/amazon-ecr-login@v2"
      via: "OIDC role assumption with vars.IAM_ROLE"
      pattern: "role-to-assume:.*IAM_ROLE"
    - from: "buildx push"
      to: "ECR repos portfolio-web / portfolio-api"
      via: "docker/build-push-action@v6 with tags list"
      pattern: "portfolio-(web|api):"
---

<objective>
Add a new GitHub Actions workflow that builds `portfolio-web` and `portfolio-api` images on every push to `main` touching `app/portfolio/**`, pushes both `:latest` and `:<sha>` tags to ECR, and prints digests to the job summary.

Purpose: Automates image publishing so Plan 04 (Flux image automation) has tagged images to promote.
Output: One new workflow file. No changes to existing deploy-workflow.yaml.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/02-secrets-ci-image-push/02-CONTEXT.md
@.github/workflows/deploy-workflow.yaml
@app/portfolio

<interfaces>
Existing OIDC pattern (deploy-workflow.yaml):
  permissions: id-token: write, contents: read
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ vars.IAM_ROLE }}
    role-session-name: GitHubActionsSession
    aws-region: us-east-1

ECR registry URL: 372517046622.dkr.ecr.us-east-1.amazonaws.com
Repos (from Plan 01): portfolio-web, portfolio-api
Dockerfiles (from Phase 1): app/portfolio/frontend/Dockerfile, app/portfolio/backend/Dockerfile
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Author portfolio-images.yaml (D-05)</name>
  <files>.github/workflows/portfolio-images.yaml</files>
  <action>
Create the workflow file. Structure per D-05:

- name: "Portfolio Images - Build & Push"
- on:
    push:
      branches: [main]
      paths: ['app/portfolio/**', '.github/workflows/portfolio-images.yaml']
    pull_request:
      branches: [main]
      paths: ['app/portfolio/**']
    workflow_dispatch: {}
- permissions: id-token: write, contents: read
- env: AWS_REGION: us-east-1, ECR_REGISTRY: 372517046622.dkr.ecr.us-east-1.amazonaws.com
- concurrency: group: portfolio-images-${{ github.ref }}, cancel-in-progress: false   # per D-05, avoid partial pushes

Single job `build-push` running on `ubuntu-22.04`, matrix strategy over:
  image:
    - name: portfolio-web
      context: app/portfolio/frontend
    - name: portfolio-api
      context: app/portfolio/backend

Steps:
  1. actions/checkout@v4
  2. docker/setup-buildx-action@v3
  3. aws-actions/configure-aws-credentials@v4 (OIDC, role-to-assume: ${{ vars.IAM_ROLE }}, role-session-name: GitHubActionsPortfolioImages). Only run when github.event_name != 'pull_request' (PRs build but don't need AWS).
  4. aws-actions/amazon-ecr-login@v2 (skip on PR).
  5. docker/build-push-action@v6:
       context: ${{ matrix.image.context }}
       file: ${{ matrix.image.context }}/Dockerfile
       platforms: linux/amd64
       push: ${{ github.event_name != 'pull_request' }}
       tags: |
         ${{ env.ECR_REGISTRY }}/${{ matrix.image.name }}:latest
         ${{ env.ECR_REGISTRY }}/${{ matrix.image.name }}:${{ github.sha }}
       cache-from: type=gha,scope=${{ matrix.image.name }}
       cache-to: type=gha,scope=${{ matrix.image.name }},mode=max
       provenance: false
       outputs: type=image,name=${{ env.ECR_REGISTRY }}/${{ matrix.image.name }},push-by-digest=false
     id: build
  6. Step "Write digest to summary" (only when push: true): shell bash, set -euo pipefail. Use `${{ steps.build.outputs.digest }}` (build-push-action exposes this). Append to $GITHUB_STEP_SUMMARY:
       - `${{ matrix.image.name }}`: `${{ env.ECR_REGISTRY }}/${{ matrix.image.name }}@${{ steps.build.outputs.digest }}`
     Also print SHA tag line.

Fail-fast: every `run:` block starts with `set -euo pipefail`. docker/build-push-action already exits non-zero on build failure, which fails the job — per D-05 and CI-03.

Do NOT use docker/build-push-action's `load: true` — not needed, we're pushing directly. Do NOT add arm64 (deferred). Do NOT sign images (deferred).

Avoid adding any secret references; everything flows through OIDC role + ECR login action.
  </action>
  <verify>
    <automated>python3 -c "import yaml; y=yaml.safe_load(open('.github/workflows/portfolio-images.yaml')); assert 'portfolio-web' in str(y) and 'portfolio-api' in str(y); assert y.get('on', {}).get('push', {}).get('paths') == ['app/portfolio/**', '.github/workflows/portfolio-images.yaml']; assert 'concurrency' in y; assert y['concurrency']['cancel-in-progress'] is False"</automated>
  </verify>
  <done>YAML is valid, references the two ECR repos, gates push on non-PR events, and follows the existing OIDC pattern.</done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 2: Trigger workflow and confirm digests surface in summary</name>
  <what-built>
`.github/workflows/portfolio-images.yaml` is committed. IAM perms to push ECR are attached (Plan 02 Task 3). ECR repos exist (Plan 01 applied).
  </what-built>
  <how-to-verify>
1. Merge the PR containing this phase's changes to `main` (or run `gh workflow run portfolio-images.yaml --ref main` after first merge).
2. Watch the run:
     gh run watch $(gh run list --workflow=portfolio-images.yaml --limit 1 --json databaseId -q '.[0].databaseId')
3. Confirm both matrix jobs (`build-push (portfolio-web)`, `build-push (portfolio-api)`) succeed.
4. Open the run summary in the browser and confirm both digest lines appear (format: `portfolio-web: 372517046622.dkr.ecr.us-east-1.amazonaws.com/portfolio-web@sha256:...`).
5. Verify in ECR:
     aws ecr list-images --repository-name portfolio-web --query 'imageIds[?imageTag==`latest`]'
     aws ecr list-images --repository-name portfolio-api --query 'imageIds[?imageTag==`latest`]'
   Both must return at least one entry, plus a SHA-tagged image matching the commit SHA.
6. (Negative test) Open a PR against main touching `app/portfolio/backend/`: workflow runs, logs show "push: false" (skipped login), no new tag appears in ECR.
  </how-to-verify>
  <resume-signal>Reply "verified" with both digest values, or describe failures.</resume-signal>
</task>

</tasks>

<verification>
- Workflow file parses as YAML.
- On merge to main, both images present in ECR with `:latest` and `:<sha>`.
- Job summary contains both digest lines.
- PR run does not push.
</verification>

<success_criteria>
Every push to main under `app/portfolio/**` auto-builds and publishes both images; digests are discoverable. Maps to ROADMAP success criteria #3 and #4, REQ CI-01, CI-02, CI-03.
</success_criteria>

<output>
After completion, create `.planning/phases/02-secrets-ci-image-push/02-03-SUMMARY.md`. Record the first successful run URL and digests.
</output>
