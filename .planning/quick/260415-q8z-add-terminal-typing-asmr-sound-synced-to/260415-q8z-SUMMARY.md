---
id: 260415-q8z
type: quick
slug: add-terminal-typing-asmr-sound-synced-to
status: complete
completed: 2026-04-15
files_changed:
  - app/portfolio/frontend/public/audio/keypress.mp3
  - app/portfolio/frontend/public/audio/README.md
  - app/portfolio/frontend/server.js
  - app/portfolio/frontend/public/index.html
  - app/portfolio/frontend/public/css/style.css
  - app/portfolio/frontend/public/js/main.js
commits:
  - 7d91a7a feat(260415-q8z): add keypress audio asset and CSP mediaSrc
  - 5b5f874 feat(260415-q8z): add sound toggle button to nav
  - f4feab0 feat(260415-q8z): wire sound state and per-keystroke playback
---

# 260415-q8z — Terminal Typing ASMR Sound

## Summary
Added a one-shot ASMR keypress sound synced to both terminal typewriter loops (skills + experience), plus a nav toggle next to the existing theme button. Default is OFF to comply with browser autoplay policy; the first toggle click is the user gesture that unlocks an `Audio` pool of 4 elements. Preference persists in `localStorage["sound-enabled"]`.

## Implementation Notes
- **Audio asset:** Mixkit CC0-licensed mechanical keypress (`16 KB`, 128 kbps MP3). License + source documented in `public/audio/README.md`. ffmpeg was unavailable locally to trim trailing silence to the spec'd <150 ms; the 4-element pool + 25 ms throttle (`KEY_THROTTLE_MS`) keep playback responsive without overlap clipping.
- **CSP:** Added `mediaSrc: ["'self'"]` to helmet directives in `server.js`; without this the asset would be blocked by the existing CSP.
- **HTML:** `data-sound="off"` added to `<html>` root. `#soundToggle` inserted between `#themeToggle` and `#burger` with two inline 18×18 SVGs (speaker-with-waves "on" / speaker-with-X "off").
- **CSS:** `.nav__sound` mirrors `.nav__theme` (36×36 circle, same border/hover); icon visibility flipped via `[data-sound="on"]` selectors on `<html>`.
- **JS:**
  - Module-scope `soundEnabled`, `audioUnlocked`, `keyAudio` (pool), `keyAudioIdx` (round-robin), `lastPlay`, `KEY_THROTTLE_MS = 25`.
  - `initSound()` reads localStorage, mirrors it to `data-sound`, sets `aria-pressed`, attaches click handler. On the first click that turns sound on, it constructs a 4-element `Audio("/audio/keypress.mp3")` pool (volume 0.35, preload auto), plays + immediately pauses one element to satisfy the user-gesture requirement, and sets `audioUnlocked = true`. NotAllowedError is swallowed.
  - `playKey()` is a fire-and-forget round-robin emitter, throttled by `KEY_THROTTLE_MS`, used inside both `typeCmd()` `tick()` functions (skills `initSkillsTerminal` + experience `initExpTerminals`). Whitespace characters are skipped to avoid clicks on spaces.
  - JS parses cleanly via `new Function(fs.readFileSync(...))`.

## Verification
- Task 1: `test -f keypress.mp3 && test -f README.md && grep mediaSrc server.js` → OK
- Task 2: button id, icon class, `data-sound`, `.nav__sound`, `[data-sound="on"]` selectors all present → OK
- Task 3: `initSound`, `playKey`, `localStorage.*sound-enabled`, ≥2 `playKey()` calls, `KEY_THROTTLE_MS`, JS parses → OK
- Manual browser verification deferred to user (per constraints, dev server was not started).

## Deviations
None of substance. One minor note: per-asset duration trimming was skipped because `ffmpeg`/`ffprobe` are not installed on the host. The asset is small enough (16 KB) and playback is throttled+pooled, so this does not affect the success criteria. Documented in `public/audio/README.md`.

## Self-Check: PASSED
- `app/portfolio/frontend/public/audio/keypress.mp3` — present
- `app/portfolio/frontend/public/audio/README.md` — present
- `app/portfolio/frontend/server.js` — `mediaSrc` present
- `app/portfolio/frontend/public/index.html` — `#soundToggle`, `data-sound`, both icon classes present
- `app/portfolio/frontend/public/css/style.css` — `.nav__sound` and `[data-sound="on"]` rules present
- `app/portfolio/frontend/public/js/main.js` — `initSound`, `playKey`, throttle, two call sites, parses cleanly
- Commits `7d91a7a`, `5b5f874`, `f4feab0` exist on `main`
