# YLapiano — Falling-notes game backlog (Now / Next / Later)

**Goal (Onur, 2026-06):** make it **fun to play**, **convincing to re-play**, and a real path to **play better**. Three different jobs — don't conflate them.

## NOW — built, verify on device

The _fun-to-play_ feel is largely done; confirm it before building on top.

- Hit feel: note pop + particles + combo + celesta sparkle — ✅ committed
- Metronome synced to the falling blocks (one clock, no drift) — ✅
- 4-beat lead-in so note one is hittable (was: always late) — ✅
- End-of-song result: 1–3 stars + one-tap replay — ✅ (mascot art = PARKED)

**Kill/keep gate:** play it. If landing notes doesn't feel good, fix the feel before anything below. (Owner: Onur, device test.)

## NEXT — the replay hook (the biggest lever for "convincing to re-play")

A single end screen isn't a replay engine. The hook is **a beatable target**.
Owner: **Defne** (design) → **Diego/Khalid** (juice). Revisit trigger: device test confirms the feel is fun.

- **Beat your best:** persist best stars per song; the goal becomes "get 3."
- **Near-miss clarity:** show _which_ notes were missed, gently, so the kid knows what to retry — not a dead-end screen.
- **Make the retry irresistible:** "2 of 3 — one more!" with the replay button right there.

## LATER — play better (mastery / progression)

Owner: **Defne + Marco**. Trigger: replay hook proven to land in playtest.

- Difficulty/tempo ramp: start slow, speed up as a song gets 3-starred.
- Practice the notes they keep missing (miss-specific).
- Guided → unguided as they improve.

## PARKED — revisit, don't drop

- **Mascot identity (squirrel or not)** — Aiko's call. Decoration on the reward, _not_ the replay engine. Trigger: once the replay loop is proven, then polish art (OpenArt).
- **Backing-track vs kid-plays** (Guitar-Hero-style) — flagged; decide with Defne if replay needs it.
- **Score HUD / progression map / unlocks** — only if the star-replay loop proves out. Not before.
