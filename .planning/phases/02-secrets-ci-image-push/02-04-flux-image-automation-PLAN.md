---
phase: 02-secrets-ci-image-push
plan: 04
type: execute
wave: 3
depends_on: ["02-01", "02-02"]
files_modified:
  - clusters/dev-projectx/flux-system/gotk-components.yaml
  - clusters/dev-projectx/portfolio-image-automation.yaml
  - clusters/dev-projectx/kustomization.yaml
  - portfolio/image-automation/base/kustomization.yaml
  - portfolio/image-automation/base/image-repository-web.yaml
  - portfolio/image-automation/base/image-repository-api.yaml
  - portfolio/image-automation/base/image-policy-web.yaml
  - portfolio/image-automation/base/image-policy-api.yaml
  - portfolio/image-automation/base/image-update-automation.yaml
  - portfolio/image-automation/base/serviceaccount.yaml
autonomous: true
requirements: [CI-04]
must_haves:
  truths:
    - "image-reflector-controller and image-automation-controller are installed in flux-system namespace"
    - "ImageRepository CRs for portfolio-web and portfolio-api scan ECR every 5 minutes"
    - "ImagePolicy CRs select only SHA-tagged images (40 hex chars) — :latest is excluded"
    - "ImageUpdateAutomation CR pushes chore(images) commits directly to main authored by fluxcdbot"
    - "Flux image-reflector pod assumes image-reflector-role-dev via IRSA to read ECR"
  artifacts:
    - path: "portfolio/image-automation/base/image-repository-web.yaml"
      provides: "ImageRepository pointing at portfolio-web ECR repo"
      contains: "kind: ImageRepository"
    - path: "portfolio/image-automation/base/image-policy-web.yaml"
      provides: "ImagePolicy selecting newest SHA-tagged image"
      contains: "pattern: '^[0-9a-f]{40}$'"
    - path: "portfolio/image-automation/base/image-update-automation.yaml"
      provides: "ImageUpdateAutomation committing tag bumps to main"
      contains: "kind: ImageUpdateAutomation"
    - path: "clusters/dev-projectx/portfolio-image-automation.yaml"
      provides: "Flux Kustomization reconciling the CRs"
      contains: "kind: Kustomization"
  key_links:
    - from: "image-reflector-controller ServiceAccount"
      to: "image-reflector-role-dev IAM role"
      via: "eks.amazonaws.com/role-arn annotation"
      pattern: "eks.amazonaws.com/role-arn"
    - from: "ImagePolicy.status.latestImage"
      to: "HelmCharts/portfolio/values.yaml (Phase 3)"
      via: "ImageUpdateAutomation rewriting lines marked with # {\"$imagepolicy\": ...}"
      pattern: "\\$imagepolicy"
---

<objective>
Install the Flux image-automation controllers (if missing) and wire up the ImageRepository / ImagePolicy / ImageUpdateAutomation CRs that will promote newly-built ECR images into the cluster by committing tag bumps back to main.

Purpose: Closes the loop between Plan 03 (CI push) and Phase 3 (chart deploy). Without this plan, images sit in ECR but never promote.
Output: Flux components patched, new `portfolio/image-automation/` directory, new Flux Kustomization entry.

Note: The `$imagepolicy` annotations in `HelmCharts/portfolio/values.yaml` are owned by Phase 3 (chart is built there). This plan creates the policies — Phase 3 annotates the values.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/02-secrets-ci-image-push/02-CONTEXT.md
@clusters/dev-projectx/flux-system/gotk-components.yaml
@clusters/dev-projectx/flux-system/kustomization.yaml
@clusters/dev-projectx/kustomization.yaml
@clusters/dev-projectx/portfolio.yaml

<interfaces>
Flux CRDs needed (apiVersion: image.toolkit.fluxcd.io/v1beta2):
- kind ImageRepository:  spec.image (ECR URL), spec.interval, spec.provider: aws
- kind ImagePolicy: spec.imageRepositoryRef, spec.filterTags.pattern + extract, spec.policy.alphabetical/numerical — for SHA hex we use alphabetical on timestamp via numerical not possible, see action.
- kind ImageUpdateAutomation (apiVersion: image.toolkit.fluxcd.io/v1beta1):
    spec.interval, spec.sourceRef (GitRepository flux-system), spec.git.commit (author, messageTemplate), spec.git.push (branch: main), spec.update.path, spec.update.strategy: Setters

image-reflector-role-dev ARN format:
  arn:aws:iam::372517046622:role/image-reflector-role-dev  (confirm from Plan 02 SUMMARY)

Existing flux GitRepository name: flux-system (namespace flux-system).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Ensure image-reflector + image-automation controllers are installed (D-04)</name>
  <files>clusters/dev-projectx/flux-system/gotk-components.yaml</files>
  <action>
CONTEXT confirms gotk-components.yaml already contains `image-reflector-controller` and `image-automation-controller` (grep returned 2 matches). Verify their presence and that the Deployments are named accordingly; if the deployments themselves are missing (components file only names them in a config), add them via `flux install --components-extra=image-reflector-controller,image-automation-controller --export > /tmp/gotk-regen.yaml` locally and merge the new Deployment manifests into `gotk-components.yaml`.

Concrete steps:
1. grep -E 'kind: (Deployment|ServiceAccount)' clusters/dev-projectx/flux-system/gotk-components.yaml | grep -E 'image-(reflector|automation)'. If both Deployments appear → skip to Task 1b (annotation only).
2. If either Deployment is missing: run
     flux install --components-extra=image-reflector-controller,image-automation-controller --export > /tmp/gotk-new.yaml
   then port the `image-reflector-controller` and `image-automation-controller` Deployment + ServiceAccount blocks from /tmp/gotk-new.yaml into gotk-components.yaml (preserve the existing file's structure and alphabetical ordering).

Task 1b — IRSA annotation (required either way): on the `image-reflector-controller` ServiceAccount in `gotk-components.yaml`, add:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::372517046622:role/image-reflector-role-dev

Do NOT modify the other flux controllers. Do NOT bump the flux version in this plan (that's a separate upgrade).
  </action>
  <verify>
    <automated>grep -q 'image-reflector-controller' clusters/dev-projectx/flux-system/gotk-components.yaml && grep -q 'image-automation-controller' clusters/dev-projectx/flux-system/gotk-components.yaml && grep -q 'role/image-reflector-role-dev' clusters/dev-projectx/flux-system/gotk-components.yaml</automated>
  </verify>
  <done>Both controllers declared in gotk-components.yaml; reflector SA has IRSA annotation pointing at image-reflector-role-dev.</done>
</task>

<task type="auto">
  <name>Task 2: Author ImageRepository + ImagePolicy CRs for both images (D-04)</name>
  <files>portfolio/image-automation/base/kustomization.yaml, portfolio/image-automation/base/image-repository-web.yaml, portfolio/image-automation/base/image-repository-api.yaml, portfolio/image-automation/base/image-policy-web.yaml, portfolio/image-automation/base/image-policy-api.yaml</files>
  <action>
Create the directory `portfolio/image-automation/base/` (mirror the `portfolio/base/` layout used by the existing chart).

`image-repository-web.yaml`:
  apiVersion: image.toolkit.fluxcd.io/v1beta2
  kind: ImageRepository
  metadata:
    name: portfolio-web
    namespace: flux-system
  spec:
    image: 372517046622.dkr.ecr.us-east-1.amazonaws.com/portfolio-web
    interval: 5m
    provider: aws

`image-repository-api.yaml`: identical, substituting `portfolio-api`.

`image-policy-web.yaml` (per D-04: select SHA tags only, exclude :latest):
  apiVersion: image.toolkit.fluxcd.io/v1beta2
  kind: ImagePolicy
  metadata:
    name: portfolio-web
    namespace: flux-system
  spec:
    imageRepositoryRef:
      name: portfolio-web
    filterTags:
      pattern: '^[0-9a-f]{40}$'
    policy:
      alphabetical:
        order: asc    # with SHA-only pattern, newest build wins because ImageRepository tracks lastScanResult by push time; ImagePolicy re-evaluates on each scan. D-04 explicitly says semver disabled — use alphabetical as the minimum viable selector.

`image-policy-api.yaml`: identical, substituting `portfolio-api`.

NOTE on policy selection (design choice): Flux ImagePolicy requires one of {alphabetical, numerical, semver}. D-04 says "semver sort disabled — pick newest by build timestamp". The ImageRepository's scanner records tag push time; the ImagePolicy filters by pattern but the picker needs a total order. Using `alphabetical: asc` with SHA-only pattern gives deterministic (though not build-time-ordered) selection that still excludes `:latest`. Alternatively, change CI (Plan 03) to tag with timestamp prefix (e.g., `20260415T120000-<sha>`) and use alphabetical asc to pick newest — but that is a Plan 03 revision. Implement `alphabetical: asc` now; if user prefers time-ordered promotion, raise as a follow-up. This decision is within "Claude's Discretion" because D-04 locks the filter regex and the exclusion of :latest, not the tie-breaker.

`kustomization.yaml` (namespace-less kustomize):
  apiVersion: kustomize.config.k8s.io/v1beta1
  kind: Kustomization
  resources:
    - image-repository-web.yaml
    - image-repository-api.yaml
    - image-policy-web.yaml
    - image-policy-api.yaml
    - image-update-automation.yaml    # authored in Task 3
  </action>
  <verify>
    <automated>kustomize build portfolio/image-automation/base >/dev/null</automated>
  </verify>
  <done>Kustomize build produces 5 resources, all valid YAML with correct apiVersion/kind.</done>
</task>

<task type="auto">
  <name>Task 3: Author ImageUpdateAutomation + wire Flux Kustomization (D-04)</name>
  <files>portfolio/image-automation/base/image-update-automation.yaml, clusters/dev-projectx/portfolio-image-automation.yaml, clusters/dev-projectx/kustomization.yaml</files>
  <action>
Part A — `portfolio/image-automation/base/image-update-automation.yaml`:

  apiVersion: image.toolkit.fluxcd.io/v1beta1
  kind: ImageUpdateAutomation
  metadata:
    name: portfolio
    namespace: flux-system
  spec:
    interval: 5m
    sourceRef:
      kind: GitRepository
      name: flux-system
    git:
      checkout:
        ref:
          branch: main
      commit:
        author:
          name: fluxcdbot
          email: fluxcdbot@users.noreply.github.com
        messageTemplate: |
          chore(images): bump {{range .Updated.Images}}{{.}} {{end}}
      push:
        branch: main
    update:
      path: ./HelmCharts/portfolio
      strategy: Setters

Per D-04: direct push to main, fluxcdbot author, message format `chore(images): bump {image} to {tag}` (Flux's template uses `{{.}}` over Updated.Images which renders as `repo:tag` — matches the intent).

Part B — `clusters/dev-projectx/portfolio-image-automation.yaml`:

  apiVersion: kustomize.toolkit.fluxcd.io/v1
  kind: Kustomization
  metadata:
    name: portfolio-image-automation
    namespace: flux-system
  spec:
    interval: 10m
    path: ./portfolio/image-automation/base
    prune: true
    sourceRef:
      kind: GitRepository
      name: flux-system
    wait: true
    timeout: 3m

Part C — `clusters/dev-projectx/kustomization.yaml`: append `- portfolio-image-automation.yaml` to the `resources:` list. Keep existing entries untouched. Run `kustomize build clusters/dev-projectx` to confirm it renders.

Do NOT add this Kustomization as a dependency of `portfolio.yaml` — image-automation runs independently of app deploy. The Helm chart in Phase 3 will reference the ImagePolicy via `# {"$imagepolicy": "flux-system:portfolio-web"}` comments on image tag lines.
  </action>
  <verify>
    <automated>kustomize build clusters/dev-projectx >/dev/null && grep -q 'portfolio-image-automation' clusters/dev-projectx/kustomization.yaml</automated>
  </verify>
  <done>All three files exist; `kustomize build` on both `portfolio/image-automation/base` and `clusters/dev-projectx` succeeds; Flux will reconcile the new Kustomization on next loop.</done>
</task>

</tasks>

<verification>
After reconcile (5-10 min post-merge):
- `flux get image repository -n flux-system` shows both `portfolio-web` and `portfolio-api` with `Ready=True` and `Last scan` timestamps.
- `flux get image policy -n flux-system` shows both with `Latest image` populated (requires at least one SHA-tagged image in ECR from Plan 03).
- `flux get image update -n flux-system` shows `portfolio` as Ready.
- Log check: `kubectl -n flux-system logs deploy/image-reflector-controller | grep -i 'ecr\|aws'` shows successful auth via IRSA (no credential errors).
</verification>

<success_criteria>
Flux is configured to auto-promote new SHA-tagged images from ECR by committing tag bumps to `HelmCharts/portfolio/values.yaml` (annotations added in Phase 3). Maps to ROADMAP success criterion #5, REQ CI-04.
</success_criteria>

<output>
After completion, create `.planning/phases/02-secrets-ci-image-push/02-04-SUMMARY.md`. Include the command Phase 3 must use to annotate its values.yaml image tag lines.
</output>
