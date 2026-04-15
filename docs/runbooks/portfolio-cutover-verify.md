# Portfolio v2 — Cutover Verification Runbook

**Audience:** Operator executing the live cutover of `yedressov.com` from
the old FastAPI/EJS portfolio to the new Express + Flask portfolio.

**Precondition:** Phases 1–3 are merged to `main`, the chart publish
workflow has pushed `portfolio:0.2.0` to ECR, Flux has reconciled, and
the Sealed Secret has been re-sealed with the real Gmail app password.

---

## 0. Pre-flight

```bash
kubectl -n portfolio get pods
```

Expected: only `portfolio-web-*` and `portfolio-api-*` pods. No
`portfolio-frontend-*`, no old FastAPI pods.

```bash
kubectl -n portfolio get secret portfolio-smtp -o jsonpath='{.metadata.name}'
```

Expected: `portfolio-smtp` prints — the Sealed Secret has been decrypted.

```bash
kubectl -n portfolio get helmrelease portfolio -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

Expected: `True`.

---

## 1. Health endpoints over the gateway (VER-01)

```bash
curl -i https://yedressov.com/health
curl -i https://yedressov.com/api/health
```

Both should return `200 OK`.

- [ ] `/health` → 200
- [ ] `/api/health` → 200

---

## 2. Real email delivery (VER-02)

1. Open `https://yedressov.com/#contact` in a browser.
2. Submit the form with these exact values (so the test email is easy
   to spot in the inbox):
   - Name: `cutover-test`
   - Email: any address you control
   - Subject: `cutover-YYYYMMDD` (today's date)
   - Message: `Phase 4 cutover verification — ignore.`
3. Watch `contact@yedressov.com` — email should arrive within 30 seconds.

- [ ] Email received within 30s

---

## 3. Rate limit (VER-03a)

Send six POSTs from the same IP inside 15 minutes:

```bash
for i in $(seq 1 6); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST https://yedressov.com/api/contact \
    -H 'Content-Type: application/json' \
    -d '{"name":"ratetest","email":"a@b.co","subject":"rate","message":"rate-limit probe one two three"}'
done
```

Expected: `200 200 200 200 200 429`.

- [ ] 6th request returned `429`

---

## 4. Oversized body rejected before SMTP (VER-03b)

```bash
python3 -c "import json,sys; print(json.dumps({'name':'x','email':'x@y.z','subject':'big','message':'A'*20000}))" \
  | curl -s -o /dev/null -w "%{http_code}\n" \
      -X POST https://yedressov.com/api/contact \
      -H 'Content-Type: application/json' --data-binary @-
```

Expected: `413`.

- [ ] Oversized POST returned `413`

---

## 5. CORS preflight from hostile origin (VER-04)

```bash
curl -i -X OPTIONS https://yedressov.com/api/contact \
  -H 'Origin: https://evil.com' \
  -H 'Access-Control-Request-Method: POST' \
  -H 'Access-Control-Request-Headers: Content-Type'
```

Inspect the response headers. Expected: `Access-Control-Allow-Origin` is
either absent or NOT `https://evil.com`.

- [ ] No echoed `Access-Control-Allow-Origin: https://evil.com`

---

## 6. Old-app absence (VER-05)

```bash
kubectl -n portfolio get pods -o custom-columns=NAME:.metadata.name | \
  grep -vE '^(NAME|portfolio-web-|portfolio-api-)$' || echo "clean"
```

Expected: `clean`.

```bash
kubectl -n portfolio get deploy
```

Expected: exactly two deployments — `portfolio-web`, `portfolio-api`.

- [ ] Only new deployments remain

---

## 7. Image provenance (VER-06, VER-07)

```bash
kubectl -n portfolio get deploy portfolio-api -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n portfolio get deploy portfolio-web -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

Both should reference the new ECR repos (`portfolio-api`, `portfolio-web`)
with a 40-char SHA tag — NOT `latest`, NOT the old `images/portfolio-backend`
path.

- [ ] Backend image tag is a git SHA from the `portfolio-api` repo
- [ ] Frontend image tag is a git SHA from the `portfolio-web` repo

---

## Sign-off

Copy the checklist above with ticks into
`.planning/phases/04-production-verification/04-VERIFICATION.md` and
mark the phase complete in `.planning/ROADMAP.md`.

---

## Rollback

If any check fails and the site is serving a broken experience:

```bash
git log --oneline -20                          # locate the Phase 3 merge commit
git revert <phase-3-merge-sha>                 # create a revert commit
git push origin main
```

Flux reconciles within ~10 minutes and restores the previous HelmRelease
revision. The Sealed Secret does NOT need to be re-sealed — the old
revision referenced the same Secret name. Once the revert lands, re-run
section 0 to confirm the old pods are back and healthy, then open a
post-mortem issue before attempting cutover again.
