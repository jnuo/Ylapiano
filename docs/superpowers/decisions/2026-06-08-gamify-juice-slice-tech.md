# Decision Memo — Gamify "Juice-Led" Slice: Tech & Scope Lock

**Date:** 2026-06-08
**Owner of the call:** Marco (tech) + Anya (scope)
**Status:** LOCKED

## Question

How do we scope and target the first "make learning piano fun" slice — a
Guitar-Hero-style juice layer on the existing falling-notes mode — so it proves
the _feel_ fast without ballooning, and without creating rework later?

## Decisions

1. **Slice = juice-led.** Optimize for the single act of _hitting a correct
   note_ feeling great (pop, sound, combo escalation). Not scoring, not
   progression — those are the loop-led slice, a later week.
2. **Input = tap-only.** `MIDIBridge` stays in the tree, **dormant, not
   deleted**. Taps and MIDI already converge on `PlayerViewModel.handleKeyPressed`
   / `handleMIDIEvent`, so building juice on the _note-hit event_ means MIDI
   re-enables later for ~zero rework.
3. **Devices = iPad only. Floor = A13 (iPad 9th gen, 2021).** Below A13 is
   diminishing reach for real synth/particle perf risk — deliberate cut.
   iPhone is one `TARGETED_DEVICE_FAMILY` setting away when wanted; deferred
   because it doubles layout QA mid-iteration.
4. **Frame budget = design for 60Hz / 17ms; render at native refresh.** Every
   non-Pro iPad is 60Hz — tune feel to 17ms so it reads instant on the device
   kids actually own. Let SpriteKit present at native rate (120Hz iPads get
   smoother scroll free). **Hard rule: no feel that _depends_ on 120Hz.**
5. **Hit feedback lives in SpriteKit, not SwiftUI** — off the main-actor render
   path that MIDI input also rides; SpriteKit already present (`FallingNotesScene`)
   with `SKEmitterNode` for the burst.

## Why

- Latency budget is achievable: `AudioSession.swift` already requests a 5ms IO
  buffer @ 48kHz. Wired + warmed ≈ 15–25ms audio, 10–20ms visual — inside the
  50–100ms "feels good" window.
- Tap-only removes the CoreMIDI bg-thread + AsyncStream hop, one fewer variable
  while tuning feel.
- A13/60Hz floor maximizes reach (kid iPads skew old) and forces lean.

## Derisk before any juice is built (Marco's track)

1. **Pre-warm the tone cache** — kill the first-strike inline synthesis spike
   (`PianoSampler.play` renders a 72k-sample buffer on the main actor on first
   `(pitch,velocity)`).
2. **Consolidate the two `AVAudioEngine`s** — `AudioClock` runs a _silent_
   engine for timing; `PianoSampler` runs a _separate_ engine for sound. The
   falling-notes clock is not the engine making the sound. Make the sampler's
   engine the clock, or measure the drift and accept for the slice.
3. **Measure `outputLatency` + `ioBufferDuration`** on a real 60Hz iPad, three
   routes: built-in speaker, wired, Bluetooth. Print it; don't theorize it.

## Kill criteria (when we know we picked wrong)

- Wired / built-in-speaker audio, cache warmed, on the A13 floor device:
  **< ~30ms = green**, build the juice. **> ~60ms = stop**, the stack has an
  unexpected problem; fix that before any animation.
- Playtest: if landing a correct note doesn't make a 5–7yo grin or immediately
  retry, the juice didn't land — stop adding more.

## Explicitly NOT solving in this slice

- **Bluetooth audio latency** (100–200ms A2DP) — can't fix in code. Detect
  route → nudge "plug in" or accept. Owner: later.
- iPhone support, MIDI-specific UX/testing, scoring/stars/progression, new
  songs, reacting characters, new game modes.
- Real-keyboard skill-transfer validation — flagged risk for Defne + Mei: don't
  let "iPad-only for now" quietly become "never an instrument teacher."
