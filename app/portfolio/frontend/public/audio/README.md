# Audio Assets

## keypress.mp3

- **Source:** Mixkit — https://mixkit.co/free-sound-effects/keyboard/
- **Original asset URL:** https://assets.mixkit.co/active_storage/sfx/2580/2580-preview.mp3
- **License:** Mixkit Sound Effects Free License — free for commercial and non-commercial use, no attribution required (https://mixkit.co/license/#sfxFree).
- **Format:** MPEG ADTS layer III, 128 kbps, 44.1 kHz, ~16 KB.
- **Usage:** Played per character during the skills/experience terminal typewriter animations when the user enables the in-page sound toggle. Playback is throttled and pooled (4-element `Audio` pool) in `public/js/main.js`.

The clip contains a single mechanical key click; ffmpeg was not available locally to trim the trailing silence, but the throttle (`KEY_THROTTLE_MS = 25`) and audio pool keep playback responsive without overlap artifacts.
