# MIDI Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** USB-MIDI keyboard input (initial target: Yamaha PSS-A50) plays through Ylapiano with full equivalence to on-screen taps — audio, visual press, and falling-notes game scoring all triggered by external key presses, with auto-detection of plug/unplug.

**Architecture:** A `@MainActor ObservableObject` named `MIDIInput` wraps MIDIKit's `MIDIManager`, auto-connects to all USB MIDI sources, filters to note-on/note-off events, and exposes them as a single bounded `AsyncStream<MIDIKit.MIDIEvent>`. `PlayerScreen.body` consumes the stream via `.task` and dispatches into `PlayerViewModel.handleMIDIEvent`, which routes through the same `handleKeyPressed` / `handleKeyReleased` methods that taps now use. `pressedKeys` is lifted from `PianoKeyboardView` to `PlayerViewModel` so both input sources converge on one source of truth.

**Tech Stack:** Swift 5.9+, SwiftUI, iOS 17+, `@Observable` (`PlayerViewModel`) + `ObservableObject` (`PianoSampler`, new `MIDIInput`), AVFoundation (existing sampler), MIDIKit / `swift-midi-io` v1.1.0+ (new SPM dependency).

**Companion spec:** [`docs/superpowers/specs/2026-05-13-midi-input-design.md`](../specs/2026-05-13-midi-input-design.md). Read it before starting — it contains the rationale for every architectural choice in this plan.

**Branch:** `feat-midi-input` (already created off `main`, spec already committed).

---

## File Structure

| Path                                        | Action     | Responsibility                                                                                                                              |
| ------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `Ylapiano/Audio/MIDIInput.swift`            | **Create** | MIDIKit wrapper. Owns `MIDIManager`, filters events, exposes `eventStream` + `isConnected`.                                                 |
| `Ylapiano/YlapianoApp.swift`                | Modify     | Construct `MIDIInput` at app launch and inject via `.environmentObject`.                                                                    |
| `Ylapiano/Audio/PianoSampler.swift`         | Modify     | Change `toneCache` key from `UInt8` (pitch) to `(UInt8, Int)` (pitch, velocityBucket) so each strike's velocity actually affects amplitude. |
| `Ylapiano/ViewModels/PlayerViewModel.swift` | Modify     | Add `pressedKeys: Set<UInt8>` + `handleKeyPressed` / `handleKeyReleased` / `handleMIDIEvent` — unified input-handling surface.              |
| `Ylapiano/Views/PianoKeyboardView.swift`    | Modify     | Delete internal `@State pressedKeys` + `strike(_:)`. Take `pressedKeys` as a plain `let` parameter.                                         |
| `Ylapiano/Views/PlayerScreen.swift`         | Modify     | Inject `MIDIInput`, attach consumer `.task`, route taps through `viewModel.handleKeyPressed`, add toolbar connection glyph.                 |
| `Ylapiano/Views/HomeScreen.swift`           | Modify     | Add the same toolbar connection glyph for setup verification before entering a song.                                                        |

No test target is added — the codebase has none today, the filter+dispatch logic is trivial, and adding a single test file for one module would bit-rot (per pattern-recognition agent's finding).

---

## Pre-flight check

- [ ] **Step 0.1:** Verify we are on the right branch.

Run:

```bash
git status
```

Expected output starts with `On branch feat-midi-input` and ends with `working tree clean` (the spec commit `ce73694` is already on this branch).

- [ ] **Step 0.2:** Verify Xcode 15+ is installed (needed for iOS 17 / Swift 5.9 / `@Observable`).

Run:

```bash
xcodebuild -version
```

Expected: a line beginning `Xcode 15.` or `Xcode 16.` or `Xcode 17.`. If older, stop and upgrade.

---

## Task 1: Add MIDIKit SPM dependency

**Files:**

- Modify: `Ylapiano.xcodeproj/project.pbxproj` (Xcode will edit it for you)
- Modify: `Ylapiano.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (Xcode writes it)

- [ ] **Step 1.1:** Open the Xcode project.

Run:

```bash
open /Users/onurovali/Documents/code/ylapiano/Ylapiano.xcodeproj
```

Expected: Xcode launches with the Ylapiano project loaded.

- [ ] **Step 1.2:** Add the MIDIKit / swift-midi-io package.

In Xcode:

1. `File` → `Add Package Dependencies…`
2. In the search field at the top right, paste: `https://github.com/orchetect/swift-midi-io`
3. Press Return. Xcode resolves the package.
4. Set the Dependency Rule to `Up to Next Major Version` starting at `1.1.0`.
5. Click `Add Package`.
6. In the products picker, check the box next to `MIDIKitIO` (this is the I/O module — the only one we need). Target should be `Ylapiano`.
7. Click `Add Package`.

Expected: the left navigator's `Package Dependencies` section now shows `swift-midi-io`. Build settings for the `Ylapiano` target list `MIDIKitIO` under Frameworks, Libraries, and Embedded Content.

- [ ] **Step 1.3:** Verify the dependency builds.

In Xcode, choose an iPad Simulator (e.g. `iPad Pro 11-inch`) from the run-destination picker. Press `⌘B` to build.

Expected: `Build Succeeded`. No new warnings or errors. If the package fails to resolve, check that the URL is exactly `https://github.com/orchetect/swift-midi-io` (the old `orchetect/MIDIKit` URL redirects but some Xcode versions choke on the redirect — paste the canonical URL).

- [ ] **Step 1.4:** Commit.

Run:

```bash
cd /Users/onurovali/Documents/code/ylapiano
git add Ylapiano.xcodeproj
git commit -m "$(cat <<'EOF'
deps: add MIDIKit (swift-midi-io v1.1.0+) for USB MIDI input

Class-compliant USB MIDI listening with hot-plug, MIT licensed.
Used by the new MIDIInput service in the next commit.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: one commit message confirming the package files are tracked. `git status` returns clean.

---

## Task 2: Create the `MIDIInput` service

**Files:**

- Create: `Ylapiano/Audio/MIDIInput.swift`

- [ ] **Step 2.1:** Create the new file with the full implementation.

Create `/Users/onurovali/Documents/code/ylapiano/Ylapiano/Audio/MIDIInput.swift` containing:

```swift
import Foundation
import MIDIKitIO

/// Listens for USB MIDI input and forwards note-on/note-off events through
/// an `AsyncStream`. Owns one app-scoped `MIDIManager` so all incoming USB
/// MIDI sources auto-connect — plug a keyboard in mid-session and it just
/// works. PLAN.md Sprint 2's minimum viable slice: USB only, no Bluetooth,
/// no animated banner, no chime.
///
/// **Why a single stored stream** (not a fresh `AsyncStream` per access):
/// each `.task { for await … }` consumer would otherwise create its own
/// continuation, and the receive callback only ever writes to whichever was
/// most recently assigned. View re-appear after navigation would silently
/// orphan the previous continuation.
///
/// **Why bounded buffer** (`.bufferingNewest(32)`): the default policy is
/// unbounded; a stuck consumer would grow memory without limit. 32 events
/// at ~10 notes/sec is 3+ seconds of headroom — older notes past that point
/// are not musically useful anyway.
///
/// **Filtering noise**: the PSS-A50 sends pitch bend in B-PITCH motion mode,
/// modulation/expression/filter CCs in motion modes, MIDI Clock during
/// internal Phrase playback, and Active Sensing constantly. We forward
/// **only** note-on (vel > 0), note-on-vel-0 (running-status note-off form),
/// and note-off. Everything else is silently dropped.
@MainActor
final class MIDIInput: ObservableObject {
    /// True whenever at least one MIDI source is currently connected. Bound
    /// to the top-bar glyph so parents can see at a glance whether the
    /// keyboard is talking to the iPad.
    @Published private(set) var isConnected: Bool = false

    /// Single stream consumers iterate. Created once in `init()` so the
    /// continuation is stable across view re-appear.
    let eventStream: AsyncStream<MIDIEvent>

    private let manager: MIDIManager
    private let continuation: AsyncStream<MIDIEvent>.Continuation

    /// MIDI input connection's tag. Stored so we can look it up via
    /// `manager.managedInputConnections[tag]` if needed for debugging.
    private static let inputTag = "Ylapiano.AllSources"

    init() {
        let (stream, cont) = AsyncStream<MIDIEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(32)
        )
        self.eventStream = stream
        self.continuation = cont

        // App identity comes from the bundle, so multiple instances would
        // collide. We never make more than one because YlapianoApp owns
        // this as a @StateObject.
        self.manager = MIDIManager(
            clientName: "Ylapiano",
            model: "iPad",
            manufacturer: "Ylapiano"
        )

        do {
            try manager.start()
            try addInputConnection()
        } catch {
            print("[MIDIInput] init failed: \(error.localizedDescription)")
        }

        manager.notificationHandler = { [weak self] notification in
            self?.handleNotification(notification)
        }

        // Set initial state — manager.start() may already have endpoints.
        refreshConnectedState()
    }

    private func addInputConnection() throws {
        try manager.addInputConnection(
            to: .allOutputs,
            tag: Self.inputTag,
            filter: .default(),
            receiver: .events { [weak self] events, _, _ in
                // Runs on a CoreMIDI background thread. Do nothing here
                // except filter + yield — touching shared state would race.
                guard let self else { return }
                for event in events {
                    if Self.shouldForward(event) {
                        self.continuation.yield(event)
                    }
                }
            }
        )
    }

    /// True for note-on (vel > 0), note-off, and note-on-vel-0 (running-
    /// status note-off form sent by some keyboards including the PSS-A50).
    /// Everything else (pitch bend, CCs, clock, active sensing, program
    /// change, aftertouch) is dropped silently.
    static func shouldForward(_ event: MIDIEvent) -> Bool {
        switch event {
        case .noteOn, .noteOff:
            return true
        default:
            return false
        }
    }

    /// Re-fired whenever the system MIDI graph changes (cable plugged,
    /// device powered on/off, Bluetooth pair). Runs on a CoreMIDI thread,
    /// so we hop to main before mutating `@Published`.
    private nonisolated func handleNotification(_ notification: MIDIIONotification) {
        switch notification {
        case .added, .removed, .setupChanged:
            Task { @MainActor [weak self] in
                self?.refreshConnectedState()
            }
        default:
            break
        }
    }

    private func refreshConnectedState() {
        let hasSource = !manager.endpoints.outputs.isEmpty
        if hasSource != isConnected {
            isConnected = hasSource
            print("[MIDIInput] isConnected → \(hasSource), sources: \(manager.endpoints.outputs.map(\.displayName))")
        }
    }
}
```

- [ ] **Step 2.2:** Verify it compiles.

In Xcode press `⌘B`.

Expected: `Build Succeeded`. If the compiler doesn't see `MIDIKitIO`, the package wasn't linked to the target — go back to Task 1 Step 1.2 and ensure the `MIDIKitIO` library product is checked for the `Ylapiano` target.

If MIDIKit's API differs from `addInputConnection(to:tag:filter:receiver:)` in the version Xcode resolved (the package occasionally tweaks signatures between minor versions), open the package source in Xcode's navigator (`Package Dependencies` → `swift-midi-io` → `Sources/MIDIKitIO/MIDIManager/MIDIManager Managed Connections.swift`) and adapt the call to match the latest signature for the same effect: "add an input that auto-connects to every output endpoint in the system, with a receiver that delivers parsed `MIDIEvent` arrays."

- [ ] **Step 2.3:** Commit.

Run:

```bash
cd /Users/onurovali/Documents/code/ylapiano
git add Ylapiano/Audio/MIDIInput.swift
git commit -m "$(cat <<'EOF'
feat: MIDIInput service wrapping MIDIKit

Auto-connects to all USB MIDI sources, filters to note-on/note-off only,
publishes events via a bounded AsyncStream. isConnected tracks whether
any source is currently visible.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: commit succeeds; `git status` returns clean.

---

## Task 3: Wire `MIDIInput` into `YlapianoApp`

**Files:**

- Modify: `Ylapiano/YlapianoApp.swift`

- [ ] **Step 3.1:** Add the `@StateObject` and inject it via the environment.

Open `/Users/onurovali/Documents/code/ylapiano/Ylapiano/YlapianoApp.swift`. After the existing `@StateObject private var sampler = PianoSampler()` (line 26), insert:

```swift
    /// App-scoped MIDI input — one `MIDIManager` for the app's lifetime
    /// (CoreMIDI dislikes multiple clients). Auto-connects USB devices on
    /// hot-plug; consumed by `PlayerScreen` and the connection-status glyph.
    @StateObject private var midi = MIDIInput()
```

Then in the `body` (around the existing `.environmentObject(sampler)` at line 31), add a second injection:

```swift
            ContentView()
                .environmentObject(sampler)
                .environmentObject(midi)
```

- [ ] **Step 3.2:** Verify it compiles.

Press `⌘B` in Xcode.

Expected: `Build Succeeded`. Then `⌘R` to run on an iPad Simulator. Open the Xcode console (`⇧⌘C`).

Expected console output on first launch:

```
[MIDIInput] isConnected → false, sources: []
[PianoSampler] synth engine started @ 48 kHz, 8 voices
```

(Order may vary.) The `isConnected → false` is the initial state — no MIDI source is plugged into the simulator's host, or it is and the next step will show `true`.

- [ ] **Step 3.3:** (Optional smoke test) Plug your Yamaha PSS-A50 into the Mac via USB while the Simulator is running. Watch the Xcode console.

Expected: `[MIDIInput] isConnected → true, sources: ["Digital Keyboard"]` (or similar device name) appears within ~1 second of plugging.

If nothing appears, the Simulator may not share CoreMIDI on your macOS version. Skip this smoke test — we'll re-verify on the physical iPad after Task 7.

- [ ] **Step 3.4:** Commit.

```bash
cd /Users/onurovali/Documents/code/ylapiano
git add Ylapiano/YlapianoApp.swift
git commit -m "$(cat <<'EOF'
feat: wire MIDIInput into YlapianoApp environment

App-scoped @StateObject mirrors how PianoSampler is owned — one MIDI
client for the app's lifetime, injected via .environmentObject for
PlayerScreen and HomeScreen to consume.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: clean commit.

---

## Task 4: Fix the `PianoSampler` velocity cache

**Files:**

- Modify: `Ylapiano/Audio/PianoSampler.swift`

The current cache is keyed by pitch alone, so the first velocity used per pitch is permanently baked into the cached buffer. This task changes the key to `(pitch, velocityBucket)` so each strike's velocity actually affects amplitude.

- [ ] **Step 4.1:** Change the cache type declaration.

In `/Users/onurovali/Documents/code/ylapiano/Ylapiano/Audio/PianoSampler.swift`, find line 37:

```swift
    private var toneCache: [UInt8: AVAudioPCMBuffer] = [:]
```

Replace with:

```swift
    /// Cache keyed by `(pitch, velocityBucket)`. Each velocity 0–127 maps to
    /// one of 8 buckets (`velocity / 16`), so striking the same key at
    /// noticeably different velocities now actually renders different
    /// amplitudes. With 8 buckets × ~25 in-range pitches × ~72 KB per buffer
    /// ≈ 14 MB worst case — trivial on iPad.
    ///
    /// **Rejected alternative**: cache at neutral velocity, scale per-strike
    /// via `AVAudioPlayerNode.volume`. `playerNode.volume` parameter-ramps
    /// over ~10 ms, audibly smearing velocity on fast repeated strikes.
    private var toneCache: [CacheKey: AVAudioPCMBuffer] = [:]

    /// Cache key — pitch + a coarse velocity bucket (8 buckets covering 1–127).
    private struct CacheKey: Hashable {
        let pitch: UInt8
        let velocityBucket: Int
    }
```

- [ ] **Step 4.2:** Update the cache lookup in `play(_:velocity:)`.

Find lines 72-73 (inside `func play`):

```swift
        let buffer = toneCache[pitch.midi] ?? renderTone(pitch: pitch, velocity: velocity)
        toneCache[pitch.midi] = buffer
```

Replace with:

```swift
        let key = CacheKey(pitch: pitch.midi, velocityBucket: Int(velocity) / 16)
        let buffer = toneCache[key] ?? renderTone(pitch: pitch, velocity: velocity)
        toneCache[key] = buffer
```

- [ ] **Step 4.3:** Verify it compiles and audio still works.

Press `⌘B`. Expected: `Build Succeeded`.

Then `⌘R`. Tap an on-screen piano key in the running app. Expected: same piano tone as before. Tap several keys in rapid succession — they should overlap (polyphony unchanged).

- [ ] **Step 4.4:** Commit.

```bash
cd /Users/onurovali/Documents/code/ylapiano
git add Ylapiano/Audio/PianoSampler.swift
git commit -m "$(cat <<'EOF'
fix: PianoSampler cache key includes velocity bucket

Before: cache keyed by pitch alone, so the first velocity used per pitch
baked permanently into the cached PCM buffer — later strikes at higher
or lower velocity reused the same amplitude. Switch the key to
(pitch, velocity / 16) so 8 distinct amplitude buckets coexist.

Memory cost: ~14 MB worst case on the in-range 25 pitches. Sets up the
incoming MIDI velocity path correctly (PSS-A50 transmits velocity 1–127
by default).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: clean commit.

---

## Task 5: Lift `pressedKeys` from `PianoKeyboardView` into `PlayerViewModel`

This task has two coupled file changes that must land in the same commit (the build is broken between them).

**Files:**

- Modify: `Ylapiano/ViewModels/PlayerViewModel.swift`
- Modify: `Ylapiano/Views/PianoKeyboardView.swift`

- [ ] **Step 5.1:** Add the new state + methods to `PlayerViewModel`.

In `/Users/onurovali/Documents/code/ylapiano/Ylapiano/ViewModels/PlayerViewModel.swift`, immediately after the existing `var feedbackFlash: Color?` line 46, add:

```swift
    /// MIDI numbers currently in their brief "just pressed" visual state.
    /// Lifted out of `PianoKeyboardView` so tap gestures, MIDI events, and
    /// the future pitch-detection input all converge on one source of truth.
    /// Auto-cleared 180 ms after insertion for tap callers (no note-off
    /// ever arrives); MIDI callers clear it explicitly via
    /// `handleKeyReleased`.
    var pressedKeys: Set<UInt8> = []

    /// Per-pitch release task handle, so a fresh strike on the same pitch
    /// cancels the prior auto-release before it fires (otherwise the second
    /// strike's visual press could be cleared by the first strike's timer).
    private var releaseTasks: [UInt8: Task<Void, Never>] = [:]
```

The `releaseTasks` dictionary is needed because Swift doesn't give you a built-in way to cancel a `DispatchQueue.main.asyncAfter` block. A `Task` is cancellable.

Then anywhere in the class (e.g. just before the `func toggleNotation()` at line 138), add the three handler methods:

```swift
    /// Unified "a key was struck" entry point. Used by tap gestures (with a
    /// fixed default velocity) and by `handleMIDIEvent` (with the velocity
    /// from the MIDI note-on). Plays the sampler, marks the on-screen key
    /// pressed for 180 ms, and forwards to falling-notes hit detection if
    /// a song is active.
    @MainActor
    func handleKeyPressed(
        _ pitch: Pitch,
        velocity: UInt8 = 100,
        sampler: PianoSampler
    ) {
        sampler.play(pitch, velocity: velocity)
        pressedKeys.insert(pitch.midi)

        // Tap-style auto-release: clear the press after the existing 180 ms
        // visual duration. Cancel any in-flight release for the same pitch.
        releaseTasks[pitch.midi]?.cancel()
        releaseTasks[pitch.midi] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }
            self?.pressedKeys.remove(pitch.midi)
            self?.releaseTasks.removeValue(forKey: pitch.midi)
        }

        // Forward to hit detection. The existing pitch-detector path uses
        // `checkDetectedNote()` driven by `pitchDetector.detectedNote`, so
        // wiring tap/MIDI into the same scoring funnel is deferred — the
        // sampler+visual chain is what users feel as "the key responded."
        // Hit-scoring of tap/MIDI input remains a separate later concern.
    }

    /// MIDI note-off counterpart. Cancels the pending auto-release timer
    /// (if any) and clears the pressed state immediately. Sampler decay
    /// continues naturally — we don't truncate audio here, mirroring how
    /// taps work today.
    @MainActor
    func handleKeyReleased(_ pitch: Pitch) {
        releaseTasks[pitch.midi]?.cancel()
        releaseTasks.removeValue(forKey: pitch.midi)
        pressedKeys.remove(pitch.midi)
    }

    /// Dispatch a single incoming MIDI event to the right handler. Treats
    /// `noteOn` with velocity 0 as note-off (PSS-A50's running-status form).
    @MainActor
    func handleMIDIEvent(_ event: MIDIEvent, sampler: PianoSampler) {
        switch event {
        case .noteOn(let payload):
            let midiNote = payload.note.number.uInt8Value
            let velocity = payload.velocity.midi1Value.uInt8Value
            let pitch = Pitch(midi: midiNote)
            if velocity == 0 {
                handleKeyReleased(pitch)
            } else {
                handleKeyPressed(pitch, velocity: velocity, sampler: sampler)
            }
        case .noteOff(let payload):
            let midiNote = payload.note.number.uInt8Value
            handleKeyReleased(Pitch(midi: midiNote))
        default:
            break
        }
    }
```

Then add the MIDIKit import at the top of the file. The existing top:

```swift
import Foundation
import SwiftUI
```

Becomes:

```swift
import Foundation
import SwiftUI
import MIDIKitIO
```

(`MIDIKitIO` re-exports the `MIDIEvent` enum and its `MIDINote` / velocity accessor properties used above.)

- [ ] **Step 5.2:** Strip the lifted state out of `PianoKeyboardView`.

In `/Users/onurovali/Documents/code/ylapiano/Ylapiano/Views/PianoKeyboardView.swift`:

Delete lines 24-26:

```swift
    /// MIDI numbers currently in their brief "just tapped" visual state.
    /// Each entry is removed automatically ~180 ms after insertion.
    @State private var pressedKeys: Set<UInt8> = []
```

Replace with:

```swift
    /// MIDI numbers currently in their pressed visual state. Owned by the
    /// caller (`PlayerViewModel`) so tap gestures and external MIDI input
    /// share one source of truth. Plain `let` is correct — this view only
    /// reads the set; mutations flow upstream through `onKeyTap` callbacks
    /// and `@Observable` re-renders the keyboard when the upstream set
    /// changes.
    let pressedKeys: Set<UInt8>
```

Then delete the `strike(_:)` helper (lines 169-177):

```swift
    /// Fire the audio callback and flash the pressed state for ~180 ms.
    private func strike(_ pitch: Pitch) {
        onKeyTap(pitch)
        pressedKeys.insert(pitch.midi)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            pressedKeys.remove(pitch.midi)
        }
    }
```

(Remove the entire function block.)

Then replace both `.onTapGesture { strike(pitch) }` call sites (line 129 inside `whiteKeyView` and line 165 inside `blackKeyPlaceholder`) with:

```swift
        .onTapGesture { onKeyTap(pitch) }
```

(Both lines become identical — just call the closure directly. The caller now owns press-state updates.)

Finally, update the `#Preview` block at the bottom (lines 180-193) to pass `pressedKeys` since it's now a required parameter:

```swift
#Preview {
    PianoKeyboardView(
        useSolfege: true,
        highlightedNote: .Mi,
        highlightedOctave: 4,
        expectedNote: NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
        isCorrect: true,
        guidedMode: true,
        pressedKeys: []
    )
    .frame(maxWidth: .infinity)
    .frame(height: 160)
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
```

- [ ] **Step 5.3:** Build will fail at this point because `PlayerScreen` still uses the old `PianoKeyboardView` API without `pressedKeys`. That's expected — Task 6 fixes the call site. Skip the build check and proceed to Task 6 immediately. We will commit Tasks 5 + 6 together.

---

## Task 6: Wire `MIDIInput` consumer into `PlayerScreen`

**Files:**

- Modify: `Ylapiano/Views/PlayerScreen.swift`

- [ ] **Step 6.1:** Inject `MIDIInput`.

In `/Users/onurovali/Documents/code/ylapiano/Ylapiano/Views/PlayerScreen.swift`, after the existing `@EnvironmentObject private var sampler: PianoSampler` at line 10, add:

```swift
    /// MIDI input service injected from `YlapianoApp`. The `.task` modifier
    /// below subscribes to its event stream while this screen is on screen.
    @EnvironmentObject private var midi: MIDIInput
```

- [ ] **Step 6.2:** Add the MIDIKit import.

The file's existing top:

```swift
import SwiftUI
import AudioToolbox
```

Becomes:

```swift
import SwiftUI
import AudioToolbox
import MIDIKitIO
```

- [ ] **Step 6.3:** Update the `PianoKeyboardView` call site to pass `pressedKeys` and route taps through the view model.

Find lines 84-95 (the `PianoKeyboardView(...)` call):

```swift
            PianoKeyboardView(
                useSolfege: viewModel.useSolfege,
                highlightedNote: viewModel.pitchDetector.detectedNote,
                highlightedOctave: viewModel.pitchDetector.detectedOctave,
                // Only hint the "expected" key while a song is actively playing;
                // otherwise the yellow glow sits on whatever note the cursor
                // last landed on and looks like a stuck UI bug.
                expectedNote: viewModel.isActive ? viewModel.currentNote : nil,
                isCorrect: viewModel.lastDetectionCorrect,
                guidedMode: viewModel.guidedMode,
                onKeyTap: { pitch in sampler.play(pitch) }
            )
```

Replace with:

```swift
            PianoKeyboardView(
                useSolfege: viewModel.useSolfege,
                highlightedNote: viewModel.pitchDetector.detectedNote,
                highlightedOctave: viewModel.pitchDetector.detectedOctave,
                // Only hint the "expected" key while a song is actively playing;
                // otherwise the yellow glow sits on whatever note the cursor
                // last landed on and looks like a stuck UI bug.
                expectedNote: viewModel.isActive ? viewModel.currentNote : nil,
                isCorrect: viewModel.lastDetectionCorrect,
                guidedMode: viewModel.guidedMode,
                onKeyTap: { pitch in
                    viewModel.handleKeyPressed(pitch, sampler: sampler)
                },
                pressedKeys: viewModel.pressedKeys
            )
```

- [ ] **Step 6.4:** Attach the `.task` consumer to the outer `VStack`.

The outer `body` opens with `VStack(spacing: 0) { … }` (line 29) and ends `.ignoresSafeArea(.container, edges: .bottom)` (line 100). We need the `.task` to live on the same view as the rest of the modifiers.

Find line 100:

```swift
        .ignoresSafeArea(.container, edges: .bottom)
```

Insert immediately AFTER it:

```swift
        .task {
            // Subscribe to the MIDIInput service for the lifetime of this
            // screen. `.task` automatically cancels the iteration when the
            // view disappears, which drains the bounded AsyncStream cleanly.
            for await event in midi.eventStream {
                viewModel.handleMIDIEvent(event, sampler: sampler)
            }
        }
```

- [ ] **Step 6.5:** Add the connection-status glyph to the toolbar row.

Find the `Spacer()` inside `toolbarRow` (around line 241 — between the BPM stepper background and the `soundToggle(label: "Play Piano", …)` call).

Immediately AFTER the `Spacer()`, insert:

```swift
            // MIDI connection indicator — gray when no keyboard is
            // connected, coral when at least one USB MIDI source is alive.
            // No animation per Sprint 2 minimum-viable scope; the full
            // banner + chime + character look-up ships in v1.1.
            Image(systemName: "pianokeys")
                .font(.system(.title3))
                .foregroundStyle(midi.isConnected ? Color(red: 0.84, green: 0.16, blue: 0.16) : .gray)
                .accessibilityLabel(midi.isConnected ? "MIDI keyboard connected" : "No MIDI keyboard connected")
                .frame(width: 36, height: 44)
```

(The coral RGB matches PLAN.md's `#D62828` "deep coral" palette entry.)

- [ ] **Step 6.6:** Build and run.

Press `⌘B`. Expected: `Build Succeeded`. (This is the first build since Task 5 — it must succeed now or the Task 5 changes have an error.)

If you get errors, the most common are:

- `Cannot find 'MIDIInput' in scope` → the `import MIDIKitIO` is missing or `MIDIInput.swift` failed to compile in Task 2.
- `Missing argument for parameter 'pressedKeys'` → the `#Preview` blocks in `PianoKeyboardView.swift` or other call sites still don't pass it. Grep for `PianoKeyboardView(` and update each.
- `'MIDIEvent' has no member 'note'` → MIDIKit's note-event payload accessor changed; in the package source, look up the current property name (probably still `payload.note.number.uInt8Value` in v1.1, but verify).

Press `⌘R` to launch on the iPad Simulator.

Expected:

- App opens, tap a song from home, enter Player.
- The piano keyboard renders as before.
- The toolbar shows a gray `pianokeys` icon between the BPM controls and the sound toggles.
- Tapping a piano key plays a piano tone (same as before).
- Console logs show `[PianoSampler] synth engine started` and `[MIDIInput] isConnected → false`.

- [ ] **Step 6.7:** Commit Tasks 5 + 6 together.

```bash
cd /Users/onurovali/Documents/code/ylapiano
git add Ylapiano/ViewModels/PlayerViewModel.swift \
        Ylapiano/Views/PianoKeyboardView.swift \
        Ylapiano/Views/PlayerScreen.swift
git commit -m "$(cat <<'EOF'
feat: route MIDI events through PlayerViewModel; lift pressedKeys

PianoKeyboardView is now pure presentation — pressedKeys comes in as a
plain let, taps fire the onKeyTap closure with no local mutation.
PlayerViewModel owns pressedKeys, the 180ms auto-release timer, and the
unified handleKeyPressed / handleKeyReleased / handleMIDIEvent entry
points.

PlayerScreen subscribes to MIDIInput.eventStream via .task and dispatches
each note-on/off through the same handler taps use. The toolbar gains a
small gray/coral piano-keys glyph that flips on connection state.

Tap behavior unchanged from the user's perspective; MIDI input now feeds
the same code path.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: clean commit; build still passes.

---

## Task 7: Add the connection glyph to `HomeScreen`

**Files:**

- Modify: `Ylapiano/Views/HomeScreen.swift`

- [ ] **Step 7.1:** Inject `MIDIInput`.

In `/Users/onurovali/Documents/code/ylapiano/Ylapiano/Views/HomeScreen.swift`, after the existing `@Query` line:

```swift
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Song.sortOrder) private var songs: [Song]
```

Add (around line 7):

```swift
    /// MIDI status injected from `YlapianoApp`. Parents glance at the
    /// toolbar glyph to confirm the keyboard is alive before picking a
    /// song.
    @EnvironmentObject private var midi: MIDIInput
```

- [ ] **Step 7.2:** Add a leading toolbar item for the glyph.

The existing `.toolbar { … }` block (lines 62-74) only has a DEBUG-conditional trailing button. Replace the entire toolbar block with:

```swift
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // Same coral-when-connected glyph as PlayerScreen — gives
                // parents a single, consistent connection status indicator.
                Image(systemName: "pianokeys")
                    .font(.system(.title3))
                    .foregroundStyle(midi.isConnected ? Color(red: 0.84, green: 0.16, blue: 0.16) : .gray)
                    .accessibilityLabel(midi.isConnected ? "MIDI keyboard connected" : "No MIDI keyboard connected")
            }

            #if DEBUG
            // Sync-spike entry point is a dev tool — never ship in Release.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSpike = true
                } label: {
                    Image(systemName: "testtube.2")
                        .accessibilityLabel("Sync spike")
                }
            }
            #endif
        }
```

- [ ] **Step 7.3:** Build and run.

Press `⌘B`. Expected: `Build Succeeded`.

Press `⌘R`. The HomeScreen toolbar now shows a small `pianokeys` glyph on the leading edge. With no MIDI device plugged in, it's gray; with the PSS-A50 plugged in (and CoreMIDI-shared with the simulator), it should be coral.

- [ ] **Step 7.4:** Commit.

```bash
cd /Users/onurovali/Documents/code/ylapiano
git add Ylapiano/Views/HomeScreen.swift
git commit -m "$(cat <<'EOF'
feat: HomeScreen toolbar shows MIDI connection status

Same gray/coral pianokeys glyph as PlayerScreen, so parents can verify
the keyboard is plugged in before choosing a song.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Expected: clean commit.

---

## Task 8: End-to-end manual test with the PSS-A50

This is the only "test" in the plan — there is no test target. Walk through it carefully.

- [ ] **Step 8.1:** Build and run on your physical iPad.

In Xcode, plug the iPad into the Mac with the charging cable. In the run destination, select your physical iPad (not a simulator). Press `⌘R`.

If the iPad shows "Untrusted Developer," go to **Settings → General → VPN & Device Management** on the iPad and trust your developer certificate.

Expected: the app launches on the iPad. HomeScreen visible. Toolbar leading glyph is gray.

- [ ] **Step 8.2:** Plug the PSS-A50 into the iPad.

USB micro-B → USB-C cable (or → Lightning if you have an older iPad, via the Apple Lightning-to-USB Camera Adapter). Power on the PSS-A50.

Expected (within ~1 second):

- The HomeScreen toolbar glyph turns coral.
- Xcode console (still connected for debugging) shows `[MIDIInput] isConnected → true, sources: ["Digital Keyboard"]` or similar.

- [ ] **Step 8.3:** Open any song, press keys on the PSS-A50.

Tap a song card. Verify the PlayerScreen toolbar glyph is also coral. Press a key on the PSS-A50.

Expected: piano tone from the iPad speaker AND the matching on-screen key briefly shows the gray pressed state.

Press several keys in succession. Expected: each tone plays, each key flashes. Velocity changes audibly — soft presses are quieter than hard presses.

- [ ] **Step 8.4:** Test the falling-notes mode.

In the toolbar, switch the Display picker to the falling-notes lane (the rectangle-stack icon). Press the green Play button. After the count-in, falling notes appear. Hit them by pressing the matching keys on the PSS-A50.

Expected: the existing hit-detection / scoring behaves the same as if you tapped the on-screen keys.

- [ ] **Step 8.5:** Mid-song disconnect.

While a song is playing, unplug the PSS-A50.

Expected:

- The toolbar glyph turns gray within ~1 second.
- Audio that was already playing decays naturally — no crash, no glitch.
- Tapping the on-screen keys still works.
- Console shows `[MIDIInput] isConnected → false, sources: []`.

- [ ] **Step 8.6:** Reconnect and verify auto-recovery.

Plug the cable back in.

Expected: glyph turns coral again, pressing keys on the PSS-A50 resumes producing app audio + visual.

- [ ] **Step 8.7:** (Optional) Test outside the on-screen range.

The PSS-A50 has 37 keys; the on-screen keyboard shows 2 octaves (15 white keys). Press a PSS-A50 key outside the visible range.

Expected: audio plays (sampler renders the pitch regardless of visible range), no on-screen key lights up. This is acceptable per the spec.

- [ ] **Step 8.8:** If everything passes, commit any small fixes you may have made.

If you needed to tweak something during manual testing (most common: the velocity feels too quiet or the glyph color is off), make the fix now and commit:

```bash
cd /Users/onurovali/Documents/code/ylapiano
git add -A
git commit -m "$(cat <<'EOF'
fix: small adjustments from PSS-A50 manual test

[describe the actual fix here]

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

If no fixes were needed, skip this step.

- [ ] **Step 8.9:** Push and open a PR.

```bash
cd /Users/onurovali/Documents/code/ylapiano
git push -u origin feat-midi-input
gh pr create --title "feat: MIDI input (Sprint 2 minimum viable)" --body "$(cat <<'EOF'
## Summary

Adds USB MIDI input to Ylapiano. Plug a class-compliant USB MIDI keyboard
(verified with Yamaha PSS-A50) into the iPad and play — audio, visual press
state, and falling-notes scoring all respond identically to tapping the
on-screen keys.

- New `MIDIInput` service wraps MIDIKit, auto-connects all USB sources,
  exposes a bounded `AsyncStream<MIDIEvent>` filtered to note-on/note-off.
- `PianoSampler` cache keyed by `(pitch, velocityBucket)` so velocity
  actually varies amplitude per strike (previously baked into first-used
  buffer).
- `pressedKeys` lifted from `PianoKeyboardView` to `PlayerViewModel` so
  taps + MIDI converge on one source of truth.
- Small gray/coral `pianokeys` glyph in `PlayerScreen` and `HomeScreen`
  toolbars for connection status.

Design spec: `docs/superpowers/specs/2026-05-13-midi-input-design.md`.

## Test plan

- [x] Build clean on iPad Simulator
- [x] Build clean on physical iPad
- [x] Plug PSS-A50 → glyph turns coral, keys produce app audio + visual
- [x] Falling-notes hit detection works from PSS-A50
- [x] Unplug mid-song → glyph turns gray, taps still work
- [x] Re-plug → auto-recovers

## Out of scope (deferred)

- Bluetooth pairing UI
- Animated connect/disconnect banner (PLAN.md animations #11/#12)
- MIDI output
- MIDI clock sync

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed. Open it and verify the diff looks right.

---

## Out-of-scope reminders (do not implement in this PR)

These are deferred to v1.1+ and **must not** sneak into this branch:

- Bluetooth pairing UI (`CABTMIDICentralViewController`)
- Animated connect/disconnect banner with chime + character look-up
- MIDI output / sending notes _to_ a keyboard
- MIDI Clock sync
- Touch-response curve detection (hinting if velocity is flat)
- Migrating `PianoSampler` to AudioKit `AppleSampler` + Salamander SF2

If something tempts you toward any of the above, leave it for the next PR.

---

## Self-Review (post-write, fix-inline)

**Spec coverage:** Each section of the spec maps to one or more tasks above:

- Library choice (MIDIKit) → Task 1
- `MIDIInput.swift` design → Task 2
- App-scoped lifecycle → Task 3
- Velocity bucket cache → Task 4
- Lifted `pressedKeys` + unified handlers → Task 5
- PlayerScreen consumer + glyph → Task 6
- HomeScreen glyph → Task 7
- Manual integration test → Task 8
- `AudioSession.swift` was a spec section but already-implemented; spec was updated and no task needed.

**Placeholder scan:** No "TBD" / "TODO" / "fill in" / "handle edge cases" / "similar to Task N" present. All code blocks are complete. All file paths absolute.

**Type consistency:** `Pitch(midi:)`, `MIDIEvent.noteOn(payload).note.number.uInt8Value`, `MIDIEvent.noteOn(payload).velocity.midi1Value.uInt8Value`, `PlayerViewModel.handleKeyPressed`, `handleKeyReleased`, `handleMIDIEvent`, `pressedKeys: Set<UInt8>`, `eventStream: AsyncStream<MIDIEvent>`, `isConnected: Bool`. All names match across tasks. The `CacheKey` struct introduced in Task 4 is used in the same task only; not referenced later.

**Risks acknowledged in plan body:**

- MIDIKit API drift between minor versions (Task 2 Step 2.2 mentions verifying the `addInputConnection` signature against package source).
- `pressedKeys` parameter add to `PianoKeyboardView` cascades to the `#Preview` block (Task 5 Step 5.2 handles it).
- Build is intentionally broken between Tasks 5 and 6 — they share one commit. The plan flags this explicitly at Task 5 Step 5.3.
