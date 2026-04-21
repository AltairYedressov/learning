---
phase: 4
status: human_needed
---

# Phase 4 Verification — Awaiting Human Execution

Phase 4 is a manual cutover runbook. The user executes
`docs/runbooks/portfolio-cutover-verify.md` against live
`https://yedressov.com` after Phases 1–3 are merged and Flux has
reconciled.

## Checklist (fill in after running the runbook)

| ID     | Check                                               | Result |
| ------ | --------------------------------------------------- | ------ |
| VER-01 | `/health` + `/api/health` → 200 through gateway     | TBD    |
| VER-02 | Real email received in `contact@yedressov.com` <30s | TBD    |
| VER-03 | 6th rapid POST → 429, oversized body → 413          | TBD    |
| VER-04 | Hostile-origin CORS preflight rejected              | TBD    |
| VER-05 | Only `portfolio-web` + `portfolio-api` pods in ns   | TBD    |
| VER-06 | Images reference new ECR repos with SHA tags        | TBD    |
| VER-07 | HelmRelease Ready, Secret materialized              | TBD    |

## Notes

Record failures, anomalies, rollback decisions here. If a check fails,
follow the Rollback section of the runbook before editing this file.
