---
phase: 4
status: deliverable-ready
---

# Phase 4 Summary

**Deliverable:** `docs/runbooks/portfolio-cutover-verify.md` — manual
cutover verification runbook covering VER-01 through VER-07.

**Per user decision (phase discussion):** no bash script, no automated
CORS probe, no CI smoke-test workflow. User executes the runbook by
hand post-merge and fills in `04-VERIFICATION.md`.

**Scope honored:**
- VER-01: health endpoints over gateway — curl check documented
- VER-02: real email delivery — manual browser submit documented
- VER-03: rate limit + body size — copy-pastable one-liners
- VER-04: hostile-origin CORS preflight — curl command documented
- VER-05: old-app absence — kubectl check documented
- VER-06, VER-07: image provenance + HelmRelease readiness — kubectl
  + jsonpath snippets

**Rollback:** documented as a single `git revert` on the Phase 3 merge
commit. Flux reconciles within 10 minutes; no secret re-sealing needed.

**Status:** Phase 4 code/docs work is complete. Actual verification
status stays `human_needed` until the user runs the runbook against
production and updates `04-VERIFICATION.md`.
