# Release Notes

## v1.1.2 (build 2) — 2026-05-13

### Features

- Sprint 0 Day 1 audio-visual sync spike: SpriteKit scene driven by an `AVAudioEngine`-derived master clock; 60 s scroll holds ~0 ms drift, proving the timebase architecture before the real game loop ships (#2)
- Sprint 1 audio engine: new `PianoSampler` with 8-voice polyphony, additive-synth piano tones, and a swap-ready interface for the upcoming Salamander SF2 (#2)
- Sprint 1 tap-to-play: the 3-octave on-screen `PianoKeyboardView` is now interactive — white + black keys fire MIDI tones with a brief press-down visual flash (#2)
- Sprint 1 repertoire: PLAN.md v1 songs seeded — Hot Cross Buns, Mary Had a Little Lamb, Twinkle Twinkle Little Star, Old MacDonald, Frère Jacques, Deniz's Lullaby (placeholder melody) (#2)

### Other

- Version management: introduced `version.json` as the single source of truth and `scripts/bump-version.sh` that syncs `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project (#2)
- Sprint 0 Day 1 commit content carried forward from earlier work on `main`; rebuilt cleanly on the feature branch (#2)
