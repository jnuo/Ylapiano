# Release Notes

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
