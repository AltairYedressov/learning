---
phase: 02-secrets-ci-image-push
plan: 05
type: execute
wave: 1
depends_on: []
files_modified:
  - HelmCharts/portfolio/templates/sealed-secret.yaml
  - HelmCharts/portfolio/README.md
autonomous: false
requirements: [SMS-01, SMS-02, SMS-03, SEC-02]
must_haves:
  truths:
    - "A committed SealedSecret manifest at HelmCharts/portfolio/templates/sealed-secret.yaml decrypts to a Secret named portfolio-smtp in the portfolio namespace"
    - "The SealedSecret contains encryptedData for SMTP_USER, SMTP_PASS, and RECIPIENT_EMAIL — no plaintext anywhere in Git"
    - "HelmCharts/portfolio/README.md documents the kubeseal seal+rotate workflow end-to-end"
    - "Only the user can produce the actual ciphertext — Claude produces the placeholder template + docs; user runs kubeseal locally"
  artifacts:
    - path: "HelmCharts/portfolio/templates/sealed-secret.yaml"
      provides: "SealedSecret CR with encryptedData for 3 keys"
      contains: "kind: SealedSecret"
    - path: "HelmCharts/portfolio/README.md"
      provides: "Rotation + seal instructions"
      contains: "kubeseal"
  key_links:
    - from: "HelmCharts/portfolio/templates/sealed-secret.yaml"
      to: "sealed-secrets controller in sealed-secrets namespace"
      via: "encrypted with controller pubkey, decrypted in-cluster"
      pattern: "encryptedData:"
    - from: "decrypted Secret portfolio-smtp"
      to: "Phase 3 backend Deployment"
      via: "envFrom.secretRef (Phase 3 wires this)"
      pattern: "portfolio-smtp"
---

<objective>
Produce the SealedSecret template consumed by the chart and the documentation that tells the user how to seal and rotate the Gmail app password. The actual encrypted payload MUST be produced by the user locally with `kubeseal` — Claude cannot access the controller's public cert safely from this context and cannot see the user's Gmail app password.

Purpose: Without a committed SealedSecret, Phase 3 cannot mount SMTP credentials into the backend pod.
Output: Template YAML (initially with placeholder encryptedData that the checkpoint step replaces), README section with seal + rotate workflow.

Per D-01 & D-06 & D-07: file lives with the chart, name `portfolio-smtp` in namespace `portfolio`, chart mount wiring belongs to Phase 3.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/02-secrets-ci-image-push/02-CONTEXT.md
@platform-tools/sealed-secrets/README.md
@HelmCharts/portfolio/Chart.yaml
@HelmCharts/portfolio/README.md

<interfaces>
Sealed Secrets controller:
  namespace: sealed-secrets
  deployment name: sealed-secrets (from base helmrelease)
  fetch cert: kubeseal --controller-namespace sealed-secrets --controller-name sealed-secrets --fetch-cert

SealedSecret CR shape:
  apiVersion: bitnami.com/v1alpha1
  kind: SealedSecret
  metadata:
    name: portfolio-smtp
    namespace: portfolio
  spec:
    encryptedData:
      SMTP_USER: <base64-ciphertext>
      SMTP_PASS: <base64-ciphertext>
      RECIPIENT_EMAIL: <base64-ciphertext>
    template:
      metadata:
        name: portfolio-smtp
        namespace: portfolio
      type: Opaque

Chart values (D-07): this plan touches ONLY templates/sealed-secret.yaml and README.md. No values.yaml, no Deployment envFrom (that's Phase 3).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Author placeholder SealedSecret template (D-01)</name>
  <files>HelmCharts/portfolio/templates/sealed-secret.yaml</files>
  <action>
Create the file with the exact structure below. Keep it OUTSIDE `{{- if .Values... }}` guards (D-01 says it ships with the chart unconditionally). Use a clearly-marked `__REPLACE_VIA_KUBESEAL__` placeholder so a committed placeholder cannot accidentally be treated as real ciphertext:

  apiVersion: bitnami.com/v1alpha1
  kind: SealedSecret
  metadata:
    name: portfolio-smtp
    namespace: {{ .Values.namespace.name | default "portfolio" }}
  spec:
    encryptedData:
      SMTP_USER: __REPLACE_VIA_KUBESEAL__
      SMTP_PASS: __REPLACE_VIA_KUBESEAL__
      RECIPIENT_EMAIL: __REPLACE_VIA_KUBESEAL__
    template:
      metadata:
        name: portfolio-smtp
        namespace: {{ .Values.namespace.name | default "portfolio" }}
      type: Opaque

Rationale:
- D-01 pins name to `portfolio-smtp`, namespace `portfolio`.
- The chart already uses `{{ .Values.namespace.name }}` in other templates per code_context; default fallback keeps helm template rendering safe if the value isn't set yet.
- Placeholder string is distinctive so CI can detect unsealed commits (future enhancement, not implemented here).

Do NOT attempt to run `kubeseal` from this plan — Claude has no path to the cluster's controller cert in this context, and doing so would also require handling the user's Gmail app password, which is explicitly their responsibility per D-06.
  </action>
  <verify>
    <automated>helm template HelmCharts/portfolio --set namespace.name=portfolio 2>/dev/null | grep -q 'kind: SealedSecret' && grep -q '__REPLACE_VIA_KUBESEAL__' HelmCharts/portfolio/templates/sealed-secret.yaml</automated>
  </verify>
  <done>Template renders via `helm template`; three placeholder encryptedData keys present.</done>
</task>

<task type="auto">
  <name>Task 2: Document seal + rotate workflow in chart README (D-06, SMS-03)</name>
  <files>HelmCharts/portfolio/README.md</files>
  <action>
Append (or create if empty) a new section `## SMTP Sealed Secret (portfolio-smtp)` to `HelmCharts/portfolio/README.md`. Content must cover D-06 exactly:

1. Prereqs:
   - `kubeseal` CLI installed locally (link: https://github.com/bitnami-labs/sealed-secrets/releases).
   - `kubectl` context set to `dev-projectx`.
   - Gmail account with 2FA enabled.

2. Generate a Gmail App Password:
   - Go to https://myaccount.google.com/apppasswords
   - App name: "portfolio-dev" (or similar)
   - Copy the 16-char password; treat as secret.

3. Fetch the sealed-secrets controller public cert:
     kubeseal --controller-namespace sealed-secrets \
              --controller-name sealed-secrets \
              --fetch-cert > /tmp/sealed-secrets-pub.pem

4. Create the plaintext Secret **locally, never commit**:
     cat > /tmp/smtp-secret.yaml <<'EOF'
     apiVersion: v1
     kind: Secret
     metadata:
       name: portfolio-smtp
       namespace: portfolio
     type: Opaque
     stringData:
       SMTP_USER: "contact@yedressov.com"
       SMTP_PASS: "<paste 16-char app password>"
       RECIPIENT_EMAIL: "contact@yedressov.com"
     EOF

5. Seal it:
     kubeseal --cert /tmp/sealed-secrets-pub.pem \
              --format yaml \
              < /tmp/smtp-secret.yaml \
              > HelmCharts/portfolio/templates/sealed-secret.yaml

6. Verify no plaintext remains:
     shred -u /tmp/smtp-secret.yaml /tmp/sealed-secrets-pub.pem
     grep -L '__REPLACE_VIA_KUBESEAL__' HelmCharts/portfolio/templates/sealed-secret.yaml   # should print the file path (placeholder gone)
     grep -L 'SMTP_PASS:.*[A-Za-z0-9+/=]\{100,\}' HelmCharts/portfolio/templates/sealed-secret.yaml   # ciphertext present

7. Commit + push — Flux reconciles; controller decrypts; Secret `portfolio-smtp` appears in the `portfolio` namespace (verify with `kubectl -n portfolio get secret portfolio-smtp`).

8. Rotation (SMS-03): revoke old app password in Google UI, generate a new one, repeat steps 3–7. The controller re-decrypts on reconcile; pods receive new envFrom values on next rollout (Phase 3 handles the rollout trigger).

9. If the controller's sealing key rotates (every 30d per the sealed-secrets base): re-run steps 3 and 5 to re-encrypt against the new pubkey. Old sealed files remain decryptable for the keyring's retention window.

Also cross-link to `platform-tools/sealed-secrets/README.md` for controller-level details.
  </action>
  <verify>
    <automated>grep -q 'portfolio-smtp' HelmCharts/portfolio/README.md && grep -q 'kubeseal --cert' HelmCharts/portfolio/README.md && grep -q 'Rotation' HelmCharts/portfolio/README.md</automated>
  </verify>
  <done>README contains the full seal + rotate procedure; SMS-03 satisfied.</done>
</task>

<task type="checkpoint:human-action" gate="blocking">
  <name>Task 3: User produces the real SealedSecret ciphertext (SMS-01, SMS-02, SEC-02)</name>
  <what-built>
The placeholder template exists at `HelmCharts/portfolio/templates/sealed-secret.yaml` and the README documents the exact commands to replace it. Claude has no access to the Gmail app password or the cluster's controller public cert in this context, so the user must run `kubeseal` locally.
  </what-built>
  <how-to-verify>
Follow the README section "SMTP Sealed Secret (portfolio-smtp)" steps 2–7. When complete:

1. `HelmCharts/portfolio/templates/sealed-secret.yaml` no longer contains `__REPLACE_VIA_KUBESEAL__`.
2. The file contains three `encryptedData` entries whose values are long base64 strings (typically 350+ chars each).
3. `grep -Ri 'SMTP_PASS.*=' .` (excluding .git) returns ZERO plaintext matches.
4. `helm template HelmCharts/portfolio --set namespace.name=portfolio | kubectl apply --dry-run=client -f -` succeeds (sealed-secrets CRD must be installed on the local kubectl's context for full validation; otherwise `helm lint HelmCharts/portfolio` suffices).
5. After merge + Flux reconcile (5-10m), confirm decryption:
     kubectl -n portfolio get secret portfolio-smtp -o jsonpath='{.data.SMTP_USER}' | base64 -d
   Should print the Gmail username.
6. Revoke any interim app passwords in Google UI if more than one was created during testing.
  </how-to-verify>
  <resume-signal>Reply "sealed" with the git SHA of the commit containing the ciphertext, or describe issues.</resume-signal>
</task>

</tasks>

<verification>
- `helm template HelmCharts/portfolio` renders without error.
- After the checkpoint, `kubectl -n portfolio get secret portfolio-smtp` returns the decrypted Secret with three data keys.
- No plaintext SMTP credentials appear anywhere in the Git history for this commit (user verifies before push).
</verification>

<success_criteria>
Gmail app password is encrypted in Git as a SealedSecret the cluster controller can decrypt; rotation workflow documented. Maps to ROADMAP success criteria #1 and #2, REQs SMS-01, SMS-02, SMS-03, SEC-02.
</success_criteria>

<output>
After completion, create `.planning/phases/02-secrets-ci-image-push/02-05-SUMMARY.md`. Note that Phase 3 must add `envFrom: - secretRef: { name: portfolio-smtp }` to the backend Deployment.
</output>
