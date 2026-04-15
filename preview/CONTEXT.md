# Project Context for Claude

**Paste this whole file into the Claude conversation along with the 5 code files.**

---

## What this is

A single-page personal portfolio for **Altair Yedressov — Platform / DevOps / Cloud Engineer**.
Deployed on AWS EKS via Flux GitOps behind Istio. Node.js 20 + Express 4 + plain
EJS-free HTML/CSS/JS. No frameworks, no bundlers, no React. Intentionally simple
so the page stays fast and self-contained.

---

## Design language

- **Aesthetic:** dark terminal / developer-console vibe. Subtle noise overlay,
  monospace accents, green-cyan accent colors.
- **Mood:** quiet, technical, understated. Avoid Web3 / gradient-heavy /
  AI-generic looks.
- **Inspirations:** Daniasyrofi's portfolio, shadcn/ui minimalism,
  classic terminal UIs.

### Two themes (both must be supported)

| Token | Dark (default) | Light ("warm paper") |
|-------|----------------|----------------------|
| `--bg` | `#060608` | `#f8f5f0` |
| `--bg-card` | `#0e0e12` | `#ffffff` |
| `--text` | `#e2e2ea` | `#2d2a26` |
| `--text-muted` | `#8888a0` | `#6b6560` |
| `--accent` | `#00e5a0` (mint) | `#0d9668` (forest) |
| `--accent-alt` | `#00c2ff` (cyan) | `#0878a8` (steel blue) |
| `--border` | `#1f1f2a` | `#e0dbd3` |

Theme is toggled by flipping `data-theme="light"` on `<html>`.
Persisted in `localStorage` under key `theme`.

### Typography

- **Body:** `Outfit` (300–800) via Google Fonts
- **Mono:** `JetBrains Mono` (terminals, code blocks, timestamps)
- Always use `var(--font-body)` / `var(--font-mono)` — never hardcode.

### Radii / motion / scale

- `--radius: 12px` (cards), `--radius-sm: 8px` (buttons)
- `--transition: 0.3s cubic-bezier(0.25, 0.46, 0.45, 0.94)` — use for all
  hovers and theme-color transitions.
- Breakpoints: mobile-first. Burger menu kicks in under ~820px.

---

## Page structure (sections, in order)

1. **Nav** (`#nav`) — fixed top. Links: About · Skills · Experience · Contact.
   Right side: `#themeToggle` then `#burger` (mobile only).
2. **Hero** (`#hero`) — name, title, subtitle, cert badges (CKA/CKAD/Terraform/AWS-SAA),
   and a live terminal typewriter panel (`#terminalText` + `#terminalHistory`).
3. **About** (`#about`) — intro copy, stats with count-up animation (`[data-count]`).
4. **Skills** (`#skills`) — split layout:
   - Left: a second terminal that types skill categories (`#skillsTyping`,
     `#skillsTermOutput`) with a `▋` cursor.
   - Right: tag clouds revealed per category (`#vizCloud`, `#vizCicd`,
     `#vizObs`, `#vizSec`, `#vizData`, `#vizAi`, and an empty-state `#vizEmpty`).
5. **Experience** (`#experience`) — third terminal (`.exp-terminal__*`) that
   streams role bullets with prompts and dividers.
6. **Contact** (`#contact`) — GitHub-issue-styled form (`.gh__*` classes),
   posts to backend at `API_URL`.
7. **Mobile menu** (`#mobileMenu`) — overlay triggered by burger.

---

## Important interactive pieces (do not break)

| Feature | Owning JS | Key DOM | Notes |
|---------|-----------|---------|-------|
| Theme toggle | `initTheme()` | `#themeToggle`, `<html data-theme>` | Persists in localStorage key `theme` |
| Scroll-based nav shadow | `initNav()` | `.nav.scrolled` | Adds border/solid bg past 40px |
| Burger / mobile menu | `initNav()` | `#burger`, `#mobileMenu.open` | |
| Reveal-on-scroll | `initReveal()` | `.reveal`, `.reveal--d1..d3` | IntersectionObserver, adds `.reveal--visible` |
| Stat count-up | `initCountUp()` | `[data-count]` | Runs once on intersect, ease-out quart |
| Hero terminal | `initTerminal()` | `#terminalText`, `#terminalHistory` | Types commands + bullets in a loop |
| Skills terminal | `initSkills()` | `#skillsTyping`, viz category ids | Typing triggers right-side tag reveal |
| Experience terminal | `initExperience()` | `.exp-terminal__*` | Roles stream with PS1-style prompt |
| Contact form | `initContact()` | `#contactForm` | Posts JSON to `/api/contact` on backend |

The 3 terminals all use the same visual idiom: a title bar with red/yellow/green
traffic-light dots, a monospace body, a blinking cursor, and typed output.

---

## Constraints for new features

1. **Plain HTML/CSS/JS only.** No React, Vue, Svelte, jQuery, Tailwind,
   or build tooling. One `style.css`, one `main.js`.
2. **Use existing tokens** — don't invent new color variables. If you need
   a new shade, derive it from existing ones (e.g. `color-mix()` or
   `rgba(var(--accent-rgb), ...)`).
3. **Both themes must work.** If you add new colors, provide values for
   dark (`:root`) AND light (`[data-theme="light"]`).
4. **Respect `prefers-reduced-motion`** for any non-essential animation.
5. **Don't rename or remove existing IDs/classes.** JS references many of
   them by id.
6. **New external resources (fonts, audio, scripts, images):** you must
   tell me which Helmet CSP directive to extend in `server.js`. Current
   allowlist includes: `'self'`, Google Fonts (styles + fonts), and inline
   styles for the dynamic theming. Media/audio/connect-src for third-party
   hosts are NOT pre-approved.
7. **Keep it fast.** The whole thing gzips to <50KB without fonts. Don't add
   heavy libraries. If you need a small helper (animation easing, etc.),
   inline it.
8. **Accessibility:** keep `aria-label` on icon-only buttons, don't trap focus,
   keep color contrast passing WCAG AA in both themes.
9. **Mobile-first.** Test that the burger menu still works.

---

## What's forbidden (will be rejected at port time)

- Adding a bundler, TypeScript, or npm build step in the frontend.
- Importing UI libraries (shadcn, Radix, Material, Bootstrap, Tailwind).
- Inline `<script>` with secrets or API keys.
- Touching `server.js` CSP without explicitly flagging the directive change.
- Renaming files — porter relies on matching filenames.
- Adding analytics/tracking without explicit ask.

---

## What the backend provides (context only — don't modify)

- `GET /api/profile` — bio blob
- `GET /api/skills` — skill categories + tags
- `GET /api/experience` — work history
- `GET /api/certifications` — cert list
- `GET /api/projects` — project list
- `POST /api/contact` — form submission
- `GET /health` — liveness

Frontend calls the backend via `API_URL` env var (`server.js`).

---

## Deployment context (FYI — don't try to automate)

- Changes to `app/portfolio/**` → GitHub Actions builds Docker image tagged
  with commit SHA → pushed to ECR.
- Image tag is **manually** bumped in `portfolio/base/helmrelease.yaml`.
- Flux reconciles on 10-min interval (or on-demand via `flux reconcile`).
- None of this is your concern inside `preview/` — that's handled on the CLI
  side after changes are ported over.

---

## How to suggest changes

When you have a change, respond with either:

**Small change:** unified diff against the file(s) you edited.

**Larger change:** full updated file(s) so I can drop them in wholesale.

In both cases, list:
1. Which files changed
2. Any new CSP directives needed in `server.js`
3. Any tokens added to `:root` AND `[data-theme="light"]`
4. Any existing IDs/classes you removed or renamed (should be zero)
5. Browser support / reduced-motion notes
