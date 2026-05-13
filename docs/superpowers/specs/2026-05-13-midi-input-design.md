# MIDI Input — Design Spec

**Date:** 2026-05-13
**Author:** Onur (with multi-agent design review)
**Status:** Awaiting approval

## Goal

A USB-connected MIDI keyboard (initial target: Yamaha PSS-A50) plays through
Ylapiano with the same effect as tapping the on-screen keyboard:

- Audio plays through the app's `PianoSampler`
- The on-screen key shows its pressed state
- Falling-notes game registers the press for hit detection and scoring
- Velocity from the MIDI keyboard maps to playback amplitude
- Connect / disconnect is auto-detected; no user-facing pairing flow

This is the minimum viable slice of PLAN.md's Sprint 2 — USB only, no
Bluetooth, no animated banner, no chime, no character look-up.

## Scope

**In scope:**

- USB MIDI input via class-compliant device (PSS-A50 confirmed)
- Auto-connect on launch and on hot-plug
- Note-on / note-off (incl. running-status `9nH v=0` form the PSS-A50 sends)
- Velocity 1–127, mapped through the sampler
- Listening on all 16 MIDI channels (PSS-A50 arpeggio uses ch 2/3/4)
- A small static connection-status glyph in the top bar (gray / coral)
- Filtering of noisy events the PSS-A50 emits (pitch bend, control changes,
  MIDI clock, active sensing, program change, aftertouch)

**Out of scope (deferred to v1.1+):**

- Bluetooth pairing UI (`CABTMIDICentralViewController`)
- Animated connect / disconnect banner with chime + character look-up
  (PLAN.md animations #11 / #12 supersede the glyph when built)
- MIDI output (sending notes _to_ a keyboard)
- MIDI clock sync (using the keyboard's internal Phrase as a metronome source)
- Touch-response curve detection / hint when the user has flat velocity

## Dependency

**MIDIKit / `swift-midi-io`** by orchetect, v1.1.0+ (May 2026), MIT.
Source: <https://github.com/orchetect/swift-midi-io>.

Rationale: raw CoreMIDI for "listen to USB sources + hot-plug + note-on/off"
is ~150 lines of `UnsafePointer<MIDIEventList>` walking and MIDI 2.0 UMP word
decoding. MIDIKit collapses that to ~30 lines, handles the PSS-A50's
running-status note-off form correctly, exposes hot-plug as a typed
`MIDIIONotification` callback, and gives us a clean Bluetooth path when we
build that in v1.1. PLAN.md already specified MIDIKit as the locked choice.

## Architecture

```
Yamaha PSS-A50 (or any USB MIDI device)
        ↓ USB
MIDIKit.MIDIManager (background CoreMIDI thread, auto-connects .allOutputs)
        ↓ receiveHandler closure
MIDIInput (@MainActor ObservableObject, app-scoped via @StateObject)
   • filters to .noteOn / .noteOff
   • yields to a single stored AsyncStream<MIDIEvent>
                  (bufferingPolicy: .bufferingNewest(32))
   • updates @Published isConnected from MIDIKit notification handler
        ↓ AsyncStream
PlayerScreen.body's .task { for await ev in midi.eventStream { … } }
        ↓ MainActor
PlayerViewModel.handleKeyPressed(pitch, velocity) — single entry point
   • PianoSampler.play(pitch, velocity:)
   • updates pressedKeys: Set<UInt8>  (lights up on-screen key)
   • forwards to falling-notes hit detection
```

`pressedKeys` is lifted out of `PianoKeyboardView` into `PlayerViewModel`.
`PianoKeyboardView` takes `pressedKeys` as a `@Binding`. Both tap gestures
and MIDI events feed `PlayerViewModel.handleKeyPressed` — single entry point
for any input source (tap, MIDI, future pitch detection).

## File-by-file plan

### New: `Ylapiano/Audio/MIDIInput.swift` (~50 lines)

`@MainActor final class MIDIInput: ObservableObject`. Naming matches the
codebase convention (`PianoSampler`, `PitchDetector`, `Metronome`,
`AudioClock` — single noun, no `Service` / `Manager` suffix).

Responsibilities:

- Own a `MIDIKit.MIDIManager`, started in `init()`
- Configure one input connection via
  `manager.addInputConnection(to: .allOutputs, …, receiver: .events { events in … })`
- Inside the receiver closure (which runs on a CoreMIDI thread): switch on
  each `MIDIEvent`, keep only `.noteOn` / `.noteOff` (treat `noteOn vel=0` as
  note-off), yield to the stored `AsyncStream<MIDIEvent>` continuation
- Hook MIDIKit's `notificationHandler` for `.added` / `.removed` /
  `.setupChanged` — update `@Published private(set) var isConnected: Bool` on
  the main actor
- Route all session config through `AudioSession.configurePlayback()` —
  never touch `AVAudioSession.setCategory` / `setActive` directly

Stored stream lifecycle: created once in `init()` via
`AsyncStream.makeStream(of: MIDIEvent.self, bufferingPolicy: .bufferingNewest(32))`.
Continuation stored as a property. Unbounded buffering is explicitly rejected
to avoid leaks if the consumer stalls. 32 events at ~10 notes/sec is 3+
seconds of headroom — old notes past that point are useless.

The `MIDIEvent` type yielded is `MIDIKit.MIDIEvent` directly (no local wrapper
struct). One consumer, stable upstream API — wrapping is pointless
abstraction at this scale.

### Modified: `Ylapiano/Audio/PianoSampler.swift` (~10 lines)

Today's cache is `toneCache: [UInt8: AVAudioPCMBuffer]` keyed by pitch only,
with velocity baked into `renderTone`. Effect: first-velocity-wins per pitch
— subsequent strikes at different velocities still play at the first
amplitude.

Fix: change the cache key to `(pitch, velocityBucket)` where `velocityBucket`
is `Int(velocity / 16)` — 8 buckets covering 1–127. Render is unchanged
(`renderTone` keeps baking amplitude). Memory cost: ~8 × ~72 KB ≈ 576 KB per
pitch × ~25 in-range pitches ≈ 14 MB. Trivial on iPad.

Rejected alternative: cache at neutral velocity, scale per-strike via
`AVAudioPlayerNode.volume`. `playerNode.volume` parameter-ramps over ~10ms,
which causes audible velocity smearing on fast repeated strikes.

### `Ylapiano/Audio/AudioSession.swift` — no change needed

`configurePlayback()` already sets `setPreferredIOBufferDuration(0.005)` at
`AudioSession.swift:21`. Latency budget is already taken care of.

### Modified: `Ylapiano/YlapianoApp.swift` (~3 lines)

Add `@StateObject private var midi = MIDIInput()` and
`.environmentObject(midi)` next to the existing sampler. App-scoped — one
CoreMIDI client for the app's lifetime (CoreMIDI dislikes multiple clients).

### Modified: `Ylapiano/ViewModels/PlayerViewModel.swift` (~15 lines)

- Add `var pressedKeys: Set<UInt8> = []` (the lifted-out state)
- Add `func handleKeyPressed(_ pitch: Pitch, velocity: UInt8 = 100)` — the
  unified entry point for any "note was struck" signal. Body:
  - `sampler.play(pitch, velocity: velocity)`
  - `pressedKeys.insert(pitch.midi)`
  - Forward to existing falling-notes hit detection
  - For tap callers (no note-off ever arrives): schedule
    `pressedKeys.remove(pitch.midi)` after 180ms via a detached `Task` (or
    `DispatchQueue.main.asyncAfter`), matching the existing visual-press
    timing in `PianoKeyboardView.strike(_:)` at `PianoKeyboardView.swift:170-177`
- Add `func handleKeyReleased(_ pitch: Pitch)` for MIDI note-off (cancels
  the pending auto-release if any, removes pitch from `pressedKeys`; sampler
  decay continues naturally)
- Add `func handleMIDIEvent(_ event: MIDIKit.MIDIEvent)` that switches on
  `.noteOn` (vel > 0 → `handleKeyPressed`), `.noteOn` (vel == 0 → treat as
  note-off → `handleKeyReleased`), `.noteOff` (→ `handleKeyReleased`).
  This is the single call site `PlayerScreen`'s consumer task uses.

### Modified: `Ylapiano/Views/PianoKeyboardView.swift` (~10 lines)

Delete the internal `@State private var pressedKeys: Set<UInt8>` and the
`strike(_:)` helper. Add a plain `let pressedKeys: Set<UInt8>` parameter.
Tap gestures now call `onKeyTap(pitch)` directly without the local mutation
or the 180ms auto-release task. The caller (`PlayerScreen` →
`PlayerViewModel.handleKeyPressed`) owns the insert + auto-release.

No `@Binding` is needed because the view never mutates `pressedKeys` — it
only reads. `@Observable` on `PlayerViewModel` makes SwiftUI re-render the
keyboard when the set changes upstream. This keeps the view purely
presentational.

### Modified: `Ylapiano/Views/PlayerScreen.swift` (~25 lines)

- Inject `@EnvironmentObject private var midi: MIDIInput`
- Attach `.task { for await ev in midi.eventStream { viewModel.handleMIDIEvent(ev) } }`
  to the body
- Pass `pressedKeys: viewModel.pressedKeys` to `PianoKeyboardView` (plain value,
  not a Binding — see PianoKeyboardView change above)
- Change `onKeyTap: { pitch in sampler.play(pitch) }` at `PlayerScreen.swift:94`
  to `onKeyTap: { pitch in viewModel.handleKeyPressed(pitch) }`
- Add the connection-status glyph (SF Symbol `pianokeys`) bound to
  `midi.isConnected` — gray when false, coral when true. No animation.
  Hosted in the existing top bar at `PlayerScreen.swift:161` (toolbarRow).

### Modified: `Ylapiano/Views/HomeScreen.swift` (~10 lines)

Same status glyph in the toolbar. Bound to `midi.isConnected`. Lets parents
verify the keyboard connection from the home screen before entering a song.

## Data flow

```
[USB cable plugged in]
       ↓
MIDIKit.notificationHandler fires .added on main
       ↓
MIDIInput.isConnected = true       — @Published updates
       ↓
SwiftUI re-renders glyph as coral (PlayerScreen + HomeScreen toolbars)

[Key pressed on PSS-A50]
       ↓
CoreMIDI thread → MIDIKit receiveHandler closure (off-main)
       ↓
Filter: keep .noteOn / .noteOff (drop pitch bend, CCs, clock, sensing, PC, AT)
       ↓
continuation.yield(event)          — Sendable, thread-safe
       ↓
PlayerScreen's .task wakes on main, reads next event
       ↓
PlayerViewModel.handleKeyPressed(pitch, velocity)
       ↓
sampler.play(pitch, velocity:)     — bucketed cache lookup, then schedule
pressedKeys.insert(pitch.midi)     — SwiftUI re-renders key as pressed
hitDetection(pitch, atTime: ...)   — falling-notes scoring runs

[Cable unplugged]
       ↓
MIDIKit.notificationHandler fires .removed on main
       ↓
MIDIInput.isConnected = false
       ↓
Glyph turns gray. Taps continue to work. App does not pause or alert.
```

## Threading model

- MIDIKit's `receiveHandler` runs on a CoreMIDI thread (not a serial queue we
  control). The receiver closure must do nothing other than filter and yield
  to the continuation. `AsyncStream` continuations are documented `Sendable`
  and thread-safe.
- `MIDIInput` itself is `@MainActor` — its `isConnected` mutations from
  MIDIKit's `notificationHandler` will need an explicit
  `DispatchQueue.main.async { [weak self] in … }` if the handler fires off
  main (matching the `PitchDetector.swift:32,90,100` pattern).
- The consuming `.task { for await … }` on `PlayerScreen.body` inherits the
  view's main-actor isolation. Hop is implicit.

## Filtering rules

The PSS-A50 transmits many event types beyond notes. Inside the receiver,
forward **only**:

- `.noteOn` with `velocity > 0` → note-on
- `.noteOn` with `velocity == 0` → treat as note-off (PSS-A50's
  running-status form)
- `.noteOff` → note-off

Silently drop everything else:

- Pitch bend (sent in B-PITCH motion-effect mode)
- All control changes (modulation, volume, expression, filter sweeps,
  reverb/chorus depth, sustain — though PSS-A50 doesn't send sustain anyway)
- MIDI Clock + Start/Stop (sent during internal Phrase playback)
- Active Sensing
- Program Change
- Aftertouch (PSS-A50 doesn't send any; defensive filter)

Listen on **all 16 channels** — PSS-A50 default is ch 1 but the arpeggio
sends on ch 2/3/4.

## Error handling

- **No device connected at launch** → `isConnected` stays false, glyph stays
  gray, taps work as today. No error path.
- **MIDIKit fails to start the manager** (extremely unlikely) → log via
  `print("[MIDIInput] init failed: \(error)")` matching existing logging
  style at `PianoSampler.swift:61`. App continues tap-only.
- **Device disconnects mid-song** → glyph turns gray; song continues; taps
  still work. Kid can finish on-screen. No alert, no pause, no banner.
- **Out-of-range note pressed** (key outside the on-screen 2-octave window)
  → audio plays via sampler, no visual press has a target key. Acceptable.

## Testing

- **Manual integration test:** plug PSS-A50 into iPad via USB-C-to-microUSB
  cable. Open a song. Press keys. Verify audio + visual press + falling-notes
  scoring all behave identically to taps. Unplug mid-song, verify glyph turns
  gray and taps continue to work.
- **iOS Simulator workflow:** Simulator on macOS shares the Mac's CoreMIDI.
  If the PSS-A50 is plugged into the Mac, the simulated iPad app receives
  events. Useful for development iteration without re-plugging the cable.
- **No unit tests added.** Codebase has zero tests today; adding a single
  test target for one MIDI module would bit-rot. The decoding logic is owned
  by MIDIKit (already tested upstream); our filter + dispatch is trivial.

## Risks & open decisions

| Risk                                                                | Mitigation                                                                                                                                                     |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Velocity smearing from `playerNode.volume` ramp                     | Use bucketed cache instead — rejected the volume-scaling alternative                                                                                           |
| AsyncStream continuation leak on view re-appear                     | Single stored stream in `MIDIInput.init`; bounded buffer policy                                                                                                |
| Receiver closure touching shared mutable state from CoreMIDI thread | Closure only filters + yields; no other state mutated there                                                                                                    |
| AudioSession contention with existing `Metronome` setCategory call  | Out of scope for this spec but flagged — `Metronome.swift:28-30` ignores `AudioSession.swift:11-27` already; do not propagate that anti-pattern in `MIDIInput` |
| Mid-song disconnect leaves kid tapping a dead keyboard              | Glyph state change is the cheapest honest signal until the banner ships in v1.1                                                                                |

## Anti-patterns explicitly avoided

- No direct `AVAudioSession.setCategory` / `setActive` calls — route through
  `AudioSession`
- No second `AVAudioEngine` instance — `MIDIInput` doesn't need an engine
- No wall-clock `Timer.scheduledTimer` for event timing — events flow with
  the audio engine's render clock through the existing sampler
- No `Service` / `Manager` / `Controller` suffix in the type name —
  matches `PianoSampler` / `Metronome` / `AudioClock` convention
- No local `MIDIEvent` wrapper struct — pass MIDIKit's type directly through

## Implementation order (for the plan that follows)

1. Add MIDIKit SPM dependency to `Ylapiano.xcodeproj`
2. Write `MIDIInput.swift` and wire it into `YlapianoApp.swift`
3. Refactor `PianoSampler.swift` cache key
4. Lift `pressedKeys` out of `PianoKeyboardView` to `PlayerViewModel`,
   update PianoKeyboardView to take a `@Binding`
5. Wire `PlayerScreen` consumer task + add toolbar glyph
6. Add glyph to `HomeScreen` toolbar
7. Manual test with PSS-A50 + iPad
