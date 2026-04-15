# Preview Sandbox — Portfolio Frontend

This folder is a **self-contained copy** of the portfolio frontend UI files.
Use it when iterating on design/features with Claude in the web/desktop UI
before the changes go into the real codebase.

**Nothing in this folder is wired into the running app.** Edit freely — the
live site at `app/portfolio/frontend/` is untouched until you (or Claude CLI)
explicitly port the changes over.

---

## Files in this folder

| File | What it is | Real path |
|------|------------|-----------|
| `index.html` | Single-page portfolio markup (nav, hero, sections, EJS-free plain HTML) | `app/portfolio/frontend/public/index.html` |
| `style.css` | All styling. Uses CSS custom properties (see `:root` and `[data-theme="light"]`) | `app/portfolio/frontend/public/css/style.css` |
| `main.js` | Client-side JS: theme toggle, terminal typewriter, mobile menu, scroll reveals | `app/portfolio/frontend/public/js/main.js` |
| `server.js` | Express server (middleware, CSP headers, routing). Most UI work won't touch this. | `app/portfolio/frontend/server.js` |
| `package.json` | Node dependencies (express, helmet, compression, morgan) | `app/portfolio/frontend/package.json` |

---

## How to preview locally

### Option A — open the HTML directly (fastest)

```bash
open preview/index.html
```

Paths in `index.html` (`/css/style.css`, `/js/main.js`) are absolute, so open
won't find them. For that to work, serve the folder:

### Option B — tiny static server (recommended)

```bash
cd preview
python3 -m http.server 8000
# then open http://localhost:8000
```

### Option C — full Express server (if you want to test server.js too)

```bash
cd preview
npm install
node server.js
# then open http://localhost:3000
# (requires BACKEND API at API_URL=http://... or frontend will show degraded state)
```

---

## Rules when asking Claude for changes (paste this to Claude UI)

> I'm working on a portfolio site. I've attached 5 files from my frontend:
> `index.html`, `style.css`, `main.js`, `server.js`, `package.json`.
>
> **Constraints:**
> 1. Only touch these 5 files. Don't invent new build tools, frameworks, or
>    bundlers. Plain HTML/CSS/JS + Express only.
> 2. Keep all existing IDs, classes, and data attributes working —
>    `#themeToggle`, `#burger`, `#mobileMenu`, `.nav__*`, `.hero__*`,
>    `.terminal__*`, `.skills__*`, `.exp-terminal__*`, etc. are referenced
>    across files.
> 3. Use the existing design tokens in `:root` and `[data-theme="light"]`
>    (`--accent`, `--bg`, `--text`, `--border`, `--font-body`, `--font-mono`,
>    `--transition`, etc.). Don't hardcode colors.
> 4. Must work in BOTH themes — dark (default) and `data-theme="light"`.
> 5. Must be responsive — desktop nav + mobile burger menu already exist.
> 6. `server.js` has a CSP via `helmet` — if you add external resources
>    (fonts, media, scripts), tell me the CSP directive to add.
> 7. Don't break existing features: terminal typewriter, theme toggle,
>    scroll reveals, mobile menu.
> 8. Return updated full files or clear diffs — I'll paste them back into
>    the real repo via Claude CLI.

---

## Porting changes back to the real repo

When you're happy with a change in preview/, come back to the CLI with:

> "Port the changes from preview/{file} into app/portfolio/frontend/... —
>  compare the two and apply only the delta."

I'll diff, apply, commit atomically, push, and trigger the Flux rollout.

---

## What NOT to do here

- **Do not edit** `app/portfolio/frontend/**` manually from the UI. That's
  live code; changes trigger CI, image builds, and deploys.
- **Do not rename** files in this folder — the porting step relies on the
  same filenames.
- **Do not commit** `preview/node_modules` (there's a `.gitignore` below).
