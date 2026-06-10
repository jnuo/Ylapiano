# YLapiano Committee Brief — 2026-06-10

## Mission

Turn YLapiano from "a thin app I built for my kid" into a **complete-feeling €1 paid iOS app** (maybe €5 later) that buyers do NOT refund. We are NOT chasing perfection — we are chasing "no buyer's remorse." Output of this committee: a prioritized backlog + phased roadmap + launch plan.

## What the app is

Native iOS (SwiftUI, iOS-only, no Android). A kid (5–7) — originally built for Onur's daughter Deniz — plays songs on a **real piano/keyboard**; the app hears the notes via **microphone pitch detection** or **USB MIDI** and gives feedback. Game mode: falling notes (Guitar-Hero style) synced to a virtual keyboard display with key-glow guidance, count-in, metronome.

## Current state (v1.4.6 build 6, on TestFlight)

- **9 seeded songs:** Hot Cross Buns, Mary Had a Little Lamb, Twinkle Twinkle, Old MacDonald, Frère Jacques, Deniz's Lullaby, and 3 Catalan: La Castanyera, Plim Plim (Salta l'Esquirol), Sol Solet. Users can also add songs manually (note-entry UI — adult-only feature).
- **One song gamified:** Salta l'Esquirol has a 4-rung mastery ladder (tempo + guidance + timing windows: 50bpm/glow/±600ms floor up to harder rungs) + per-tier **Pim reward videos** (transparent mp4 mascot celebration). Other songs: plain play-through only.
- **Pim the mascot (squirrel, generated on OpenArt):** ONLY appears as app icon + post-song reward videos. Invisible everywhere else. Known issue: generated Pim is chibi style, app icon is painterly — visual canon not reconciled.
- **Home screen:** plain LazyVGrid of colored song cards + dashed "Add Song" card + MIDI status glyph. No design, no Pim, no progression/stars display, feels shallow/dev-tool-like.
- **Onboarding:** exists but weak — 3 text-heavy pages (welcome bullets, mic permission, "you're all set"). Not kid-friendly, not fun, doesn't TEACH the core interaction (put device on piano, play the glowing key, etc.). Onur considers onboarding effectively missing.
- **Sibling work in flight:** another Claude session is currently improving the single-song play experience (see product/single-song-experience-brief.md — Defne-designed mastery loop, Mei playtest gate pending on device).

## Commercial frame

- €1 one-time paid, App Store only. Launch geo: Turkey + non-EU first, EU now unlocked (DSA trader verified 2026-06-09).
- Kids Category decision PENDING (drives privacy/analytics/parental-gate rules — no third-party analytics if Kids).
- Solo dev (Onur, a PM) + Claude Code doing implementation. Effort estimates should assume AI-assisted solo dev: "S" = ~half a day, "M" = 1–2 days, "L" = 3–5 days.
- Buyer = parent. Player = kid (5–7, often pre-reader). Refund trigger = parent opens app, it looks thin/broken/confusing, kid bounces off in 2 minutes.

## Onur's open questions (address these explicitly)

1. **Onboarding/FTUE:** teach the app "in a fun game way" for a pre-reader kid + the parent setup steps (device placement, mic vs MIDI). What's the right v1?
2. **Song catalog & regional/language bundling:** he doesn't know how to structure this. Ideas: Catalan songs (origin), Turkish songs, Spanish, English (global default, e.g. Old MacDonald). How should songs be bundled/surfaced per region/language? Locale-based default packs? All-included? Pick-your-languages onboarding step? How many songs does a €1 app need to not feel thin?
3. **Pim presence:** mascot only in icon + reward videos is weird. Where else should Pim live (home screen, onboarding guide, empty states, progress companion) and what's the cheap-but-effective version?
4. **Home screen redesign:** what does "designed" look like for this app at minimal cost?
5. **Store readiness:** screenshots/listing come AFTER product completeness — what must be true in-app before screenshot day?
6. **Launch:** how to launch properly without trying to make everything perfect.

## Hard constraints

- Don't break the in-flight single-song mastery work; build around it. The mastery ladder pattern is the template for gamifying more songs.
- No backend, no accounts. Local-only (SwiftData). Keep it that way for v1.x.
- All copy must work for TR + EN locales; kid-facing UI must work for pre-readers (icons/audio over text).
- Repo: /Users/onurovali/Documents/code/ylapiano — you may read any code/docs there to verify claims (Ylapiano/Views/, Ylapiano/Game/, product/, docs/superpowers/specs/).
