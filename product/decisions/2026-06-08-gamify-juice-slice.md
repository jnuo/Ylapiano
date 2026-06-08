# Decision Log — Gamify "Juice-Led" Slice

**Date:** 2026-06-08
**Goal:** Make learning piano _feel_ like a game — Guitar-Hero-style juice on the
existing falling-notes mode. Prove the _feel_ before scoring/progression.
**Method:** game committee (Anya scope · Marco tech · Defne design · Diego motion).

## The decisions

| #   | Decision                                                                                       | Owner       | Why                                                                              |
| --- | ---------------------------------------------------------------------------------------------- | ----------- | -------------------------------------------------------------------------------- |
| 1   | **Juice-led slice** — optimize the _feeling of hitting a correct note_, not scoring            | Anya/Defne  | Fastest path to "wow"; scoring is a later (loop-led) slice                       |
| 2   | **Tap-only.** MIDI stays dormant, not deleted                                                  | Marco       | Taps + MIDI already share one event path → MIDI re-enables later for ~0 rework   |
| 3   | **iPad only**, floor = A13 (iPad 9th gen)                                                      | Marco       | Max reach (kid iPads skew old); iPhone is one build-setting away later           |
| 4   | **Design for 60Hz / 17ms; render at native refresh.** No 120Hz-dependent feel                  | Marco       | Feels instant on the device kids own; Pro gets smoother scroll free              |
| 5   | **Hit feedback in SpriteKit**, off the SwiftUI render path                                     | Marco/Diego | Keeps juice off the thread MIDI input rides                                      |
| 6   | **Hit event = right-key (required) + timing (bonus).** PERFECT ±250ms / HIT ±600ms / MISS soft | Defne       | Right-key is the lesson; generous timing because 5yos fail on input, not insight |
| 7   | **Miss is never punished**; wrong key still sounds, just no party                              | Defne/Diego | Frustration = uninstall by morning                                               |
| 8   | **No character needed** — procedural juice on shapes (no Spine/Aiko block)                     | Diego       | Slice ships without art pipeline                                                 |
| 9   | **Reduced-motion + WCAG 2.3.1 from day one** (≤3 flashes/sec)                                  | Diego       | Apple §1.3 kids reject ceiling; non-negotiable                                   |
| 10  | **Reward sparkle = celesta pitched octave-up of the played note**; combo steps a pentatonic    | Khalid      | The kid plays a real note — sparkle must be consonant; pentatonic can't clash    |
| 11  | **Sparkle −9 to −12 dB under the piano note; −18 LUFS master; fatigue test governs**           | Khalid      | Fires every note, 100s/session — must survive the parent's mute finger           |
| 12  | **No haptics** (iPads have no Taptic Engine); `.playback` session OK (it's an instrument)      | Khalid      | Honest hardware reality; piano should sound even on silent, like GarageBand      |

## Derisk before building the juice (Marco)

1. Pre-warm the tone cache (kill first-strike synthesis spike).
2. Consolidate the two `AVAudioEngine`s (the falling-notes clock is currently a
   _silent_ engine, separate from the one making sound).
3. Measure `outputLatency` on a real 60Hz iPad, 3 routes (speaker/wired/BT).
   **Green if wired/speaker < ~30ms.**

## Kill criteria

A 5-year-old presses the **right key** (not any key), grins, and reopens
unprompted on day 3. If not — the note→key _visual_ mapping is wrong, not the
windows. No piling more juice on a broken loop.

## Explicitly deferred

Bluetooth-audio latency (detect/nudge/accept), iPhone, MIDI UX, scoring/stars/
progression, new songs, hero character + idle, real-keyboard skill-transfer
validation (flagged risk: don't let "iPad-only for now" become "never an
instrument teacher").

## Detail docs

- Tech & scope lock → `docs/superpowers/decisions/2026-06-08-gamify-juice-slice-tech.md`
- Hit-event spec (numbers) → `docs/superpowers/specs/2026-06-08-hit-event-spec.md`
- Hit-juice spec (motion) → `docs/superpowers/specs/2026-06-08-hit-juice-spec.md`
- Hit-audio spec (sound) → `docs/superpowers/specs/2026-06-08-hit-audio-spec.md`

## Status

Committee design phase **complete** — scope (Anya), tech (Marco), hit-event
(Defne), motion (Diego), audio (Khalid) all locked. Ready to build.

## Next — implementation

1. **Derisk (Marco):** pre-warm tone cache · consolidate the two `AVAudioEngine`s
   · measure `outputLatency` on a 60Hz iPad (green if wired/speaker < ~30ms).
2. **Wire hit-detection:** press → which key + nearest note's ms-to-line →
   PERFECT / HIT / MISS (right-key always required for a celebration).
3. **Wire juice:** PERFECT/HIT/MISS visuals + combo in `FallingNotesScene`;
   celesta sparkle (octave-up, pentatonic combo) in the sampler.
4. **Playtest (Mei):** a 5yo presses the right key, grins, reopens day 3.
