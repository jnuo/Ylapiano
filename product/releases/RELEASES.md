# Release Notes

## v1.4.10 (build 10) — 2026-06-11

### Features

- New app icon: chibi Pim at the piano keys — the in-app character and the store icon are finally the same squirrel (#31)
- Pim's look locked as canon (chibi): greeting / pointing / cheer stills generated from one OpenArt session, shipped as transparent assets for the result card and upcoming tutorial/home screens (#31)

### Bug Fixes

- Reduced-motion 3-star result no longer references a missing image — the cheer pose shows; other tiers show the greeting wave instead of the old off-model squirrel (#31)

### Other

- Retired the painterly Mascot imageset; asset-resolution tests guard the new pack (#31)

## v1.4.9 (build 9) — 2026-06-11

### Features

- Songs now have a stable identity (`seedID` + language + difficulty): built-in songs are matched by ID instead of title, so renaming a song or creating one with the same name can never delete or hijack a user's own song (#30)
- Stores from build 6 adopt seed IDs automatically on first launch — verified with a real build-6 → build-9 upgrade simulation, user songs intact (#30)
- Localized song titles (Turkish/English, placeholders) keyed by seedID, groundwork for the Turkish build (#30)

### Other

- First test infrastructure in the repo: unit test target (10 tests on song identity/seeding) + UI test target (scripted Add Song flow) (#30)

## v1.4.8 (build 8) — 2026-06-10

### Bug Fixes

- Reward videos: removed a faint green haze that showed on the 3-star clip (the green key now fully removes a slightly washed-out backdrop instead of leaving it half-transparent).
- 3-star jump now loops naturally — regenerated so Pim jumps and lands back to the same pose, instead of the boomerang that played the jump in reverse.
- Fixed a memory leak where each finished song leaked the reward-video player (CADisplayLink retained its view, so it never deallocated). Render now runs through a weak proxy and is capped at ~30fps.

## v1.4.7 (build 7) — 2026-06-10

### Features

- Reward videos now play cleanly transparent: Pim is regenerated on a green screen and the green is keyed out in-app, replacing the white-key that left shifting marks. Each clip is boomeranged so the loop has no jump (first frame == last frame).

### Bug Fixes

- Song screen opens instantly: the abcjs web view only loads in sheet-music mode, tone prewarm is deferred past the transition, and a spinner covers the heavy panel build — no more lag when tapping a song.

## v1.4.6 (build 6) — 2026-06-10

### Features

- Single-song mastery ladder: the same song now has 4 rungs that scale tempo, guidance, and timing strictness together (50bpm/glow-on/±600ms for a 5yo floor → 120bpm/no-glow/±150ms for adult mastery). 3-star a rung to be offered the next one ("Faster!" / "Lights off!"); never forced up, never punished down (#6)
- Synced key-glow guidance returns in falling-notes mode, driven off the same clock as the falling blocks (no more drift), and dims/turns off as you climb (#6)
- End-of-song reward videos: per-tier Pim animations play in the result card — 1★ a thoughtful "hmm… try again!", 2★ a clap, 3★ a jump-cheer. White backgrounds are chroma-keyed out so Pim floats; still image + reduced-motion fallbacks (#6)
- Gameplay now locks to landscape (the keyboard needs the width) while the rest of the app rotates freely (#6)

### Bug Fixes

- Result screen no longer shows a hard-to-parse "practice these notes" report to young non-readers — it's celebrate + replay (the near-miss report is parked for the adult-tier rungs) (#6)

### Other

- Support all interface orientations and drop `UIRequiresFullScreen` (iPad multitasking requirement; clears the deprecation warnings) (#6)
- New project skills: `add-song` (transcribe a real song into the game's note format) and `pim-reward-assets` (generate Pim's tier poses + videos via OpenArt) (#6)
- Single-song product brief, design spec, and backlog added under `product/` and `docs/` (#6)

## v1.3.5 (build 5) — 2026-06-08

### Features

- USB MIDI keyboard input (Sprint 2 minimum viable): a class-compliant USB MIDI keyboard (target: Yamaha PSS-A50) plays through the app with full parity to on-screen taps — audio, visual key-press, and falling-notes scoring all route through one unified entry point. Hot-plug auto-detection; a coral `pianokeys` glyph in the `PlayerScreen` and `HomeScreen` toolbars shows live connection status (#5)
- MIDI velocity now varies playback amplitude — `PianoSampler` caches tones per `(pitch, velocityBucket)` across 8 buckets so a soft press sounds softer than a hard one (#5)

### Bug Fixes

- MIDI input survives navigating away from a song and back: the event transport now hands each screen its own stream via a thread-safe fan-out, instead of a single shared `AsyncStream` that only supported one iteration for the app's lifetime (would have silently killed MIDI after the first song) (#5)

### Other

- Switched code signing to the personal Apple developer account; added the educational app category and a full-screen single-scene manifest; migrated display-name / mic-usage / orientation keys from `Info.plist` into Xcode build settings (#5)
- `pressedKeys` lifted from `PianoKeyboardView` to `PlayerViewModel` so taps and MIDI converge on one source of truth (`handleKeyPressed` / `handleKeyReleased` / `handleMIDIEvent`) (#5)

## v1.2.4 (build 4) — 2026-05-13

### Features

- Falling-notes game mode: a toolbar toggle in PlayerScreen swaps the ABC sheet music for a SpriteKit lane where coral rectangles scroll down 15 columns aligned 1:1 with the white keys below. The bottom of each rectangle meets a red hit line directly above the key the kid needs to press at that beat (#4)
- 3-2-1-Go count-in at the song's tempo on first Play — big rounded numerals + audio tocks so anyone on a real piano can sync (#4)
- 2-octave on-screen keyboard (C3 → C5, 15 white keys) — chunkier touch targets while still covering every pitch in the v1 seed songs (#4)

### Bug Fixes

- Falling notes stay in sync after pause / resume cycles (previously the scene's own clock drifted forward by the pause duration) (#4)
- Switching display modes mid-song no longer resets the falling-notes scene to t=0 (#4)
- Tempo changes during playback now re-pace AND re-size the falling-note rectangles correctly (#4)
- Removed eager microphone-permission prompt when opening a song; the legacy pitch-detection flow isn't needed in tap-to-play and was leaving Mac Catalyst test builds with a stuck "permission denied" overlay (#4)

### Other

- New `KeyboardLayout` struct as the single source of truth for the keyboard's octave range and white-key count, shared by `PianoKeyboardView` and `FallingNotesScene` so they can't silently drift apart (#4)
- `PlayerViewModel` exposes a single `elapsedSeconds` clock (computed from a `playStartedAt: Date?` + `accumulatedBeforePause: TimeInterval` pair) for any view that needs to render in song-time; anchors are `private(set)` so the pause-then-bank invariant can only be maintained internally (#4)

## v1.1.3 (build 3) — 2026-05-13

### Features

- Squirrel mascot at the piano shipped as the new app icon (cropped tight so iOS's rounded mask doesn't shrink the visible subject) (#3)
- Standalone transparent-background `Mascot` image set bundled for upcoming HomeScreen / onboarding / celebration-card use (#3)

### Bug Fixes

- Sheet music notation rendered invisibly on physical iPads in dark mode (black SVG on black background). `MusicNotation.html` now forces a light color scheme with explicit cream `#FFF7EC` panel and deep ink `#2B2D42` text — light-mode behavior unchanged (#3)

## v1.1.2 (build 2) — 2026-05-13

### Features

- Sprint 0 Day 1 audio-visual sync spike: SpriteKit scene driven by an `AVAudioEngine`-derived master clock; 60 s scroll holds ~0 ms drift, proving the timebase architecture before the real game loop ships (#2)
- Sprint 1 audio engine: new `PianoSampler` with 8-voice polyphony, additive-synth piano tones, and a swap-ready interface for the upcoming Salamander SF2 (#2)
- Sprint 1 tap-to-play: the 3-octave on-screen `PianoKeyboardView` is now interactive — white + black keys fire MIDI tones with a brief press-down visual flash (#2)
- Sprint 1 repertoire: PLAN.md v1 songs seeded — Hot Cross Buns, Mary Had a Little Lamb, Twinkle Twinkle Little Star, Old MacDonald, Frère Jacques, Deniz's Lullaby (placeholder melody) (#2)

### Other

- Version management: introduced `version.json` as the single source of truth and `scripts/bump-version.sh` that syncs `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project (#2)
- Sprint 0 Day 1 commit content carried forward from earlier work on `main`; rebuilt cleanly on the feature branch (#2)
