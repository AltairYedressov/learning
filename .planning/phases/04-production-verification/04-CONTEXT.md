---
phase: 4
name: Production Verification & Cutover Close-Out
status: ready-for-planning
---

# Phase 4: Production Verification & Cutover Close-Out — Context

**Gathered:** 2026-04-15
**Mode:** Interactive (autonomous --interactive)

<domain>
## Phase Boundary

Verify the live site at `https://yedressov.com` after Phases 1–3 ship:
all security guardrails work in production, the contact form delivers
real email, and the old FastAPI pods are gone. Produce a single
manual runbook the user executes themselves.

</domain>

<decisions>
## Implementation Decisions (Locked)

### D-01 — Deliverable = manual runbook only
- One file: `docs/runbooks/portfolio-cutover-verify.md`.
- No bash script. No automated CORS test. No GitHub Actions workflow.
- User (per explicit answer) executes all checks themselves and records
  results in `.planning/phases/04-production-verification/04-VERIFICATION.md`.

### D-02 — Email delivery test: manual
- User fills out the form on `https://yedressov.com/#contact`, submits
  once, and confirms arrival in `contact@yedressov.com` within 30s.
- Runbook specifies exact values (name `cutover-test`, subject
  `cutover-YYYYMMDD`) so the email is easy to find.

### D-03 — CORS test: deferred to user
- Runbook lists the canonical `curl -X OPTIONS -H 'Origin: https://evil.com' ...`
  command but does NOT execute it. User runs manually and ticks the box.

### D-04 — Rollback section included
- Short paragraph in the runbook: `git revert <phase-3-merge-sha>` on
  `main`; Flux reconciles within ~10 min; no secret re-sealing needed.

### D-05 — What Phase 4 does NOT produce
- No code.
- No automated tests.
- No observability dashboards (already exist via Grafana/Thanos per
  CLAUDE.md).

</decisions>

<canonical_refs>
## Canonical References

- `.planning/ROADMAP.md` — Phase 4 goal + 5 success criteria
- `.planning/REQUIREMENTS.md` — VER-01..07
- Phase 1–3 SUMMARY + VERIFICATION files (for the human checkpoints
  that feed into the Phase 4 runbook)

</canonical_refs>
