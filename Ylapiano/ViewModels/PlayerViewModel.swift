import Foundation
import SwiftUI
import SwiftMIDIIO

@Observable
final class PlayerViewModel {
    let song: Song
    let metronome: Metronome
    let pitchDetector: PitchDetector

    var currentNoteIndex = 0
    var useSolfege = true
    var guidedMode = true
    var isPlaying = false
    var isPaused = false
    var playNotes = true
    var playMetronome = true

    /// Single source of truth for "how many seconds of *play time* have
    /// accumulated since this song's first Play." Composed of:
    ///  • `accumulatedBeforePause` — total play time banked from prior play /
    ///    pause cycles (frozen while paused).
    ///  • `playStartedAt` — wall-clock moment of the current play interval, or
    ///    `nil` while paused / stopped.
    /// `elapsedSeconds = accumulatedBeforePause + (now - playStartedAt)`. The
    /// falling-notes scene reads from here every frame so mid-song mode
    /// switches stay in sync with abcjs / the metronome.
    ///
    /// Both anchors are `private(set)` so the invariant ("accumulator banks
    /// before playStartedAt is cleared") can only be maintained inside the
    /// pause / resume / stop methods below.
    private(set) var playStartedAt: Date?
    private(set) var accumulatedBeforePause: TimeInterval = 0

    var elapsedSeconds: TimeInterval {
        if let started = playStartedAt {
            return accumulatedBeforePause + Date().timeIntervalSince(started)
        }
        return accumulatedBeforePause
    }

    var isActive: Bool { isPlaying || isPaused }
    var lastDetectionCorrect: Bool?
    var showingEditSheet = false

    // Feedback animation
    var feedbackFlash: Color?

    // MARK: - Falling-notes hit detection (juice slice)

    /// Judges taps against the song's falling-note schedule. Built once per
    /// song; reset on each fresh play.
    let hitJudge: HitJudge
    /// Most recent press outcome — the juice layer reads this to fire the
    /// PERFECT / HIT / MISS feedback. `nil` until the first judged press.
    var lastJudgment: HitJudgment?
    /// Consecutive PERFECT/HIT streak. Resets to 0 on a MISS (a broken combo
    /// just stops growing — it never punishes). Drives the escalating combo juice.
    var comboCount = 0
    /// True only while the falling-notes panel is the active mode, so taps in
    /// sheet-music mode aren't judged and notes aren't consumed.
    var fallingNotesActive = false

    /// Latest celebration for the falling-notes view to forward into the scene.
    /// `id` increments per hit so the view tells a new event from a re-render.
    var lastHit: HitEvent?
    private var hitEventCounter = 0

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

    var notes: [NoteEntry] { song.notes }
    var currentNote: NoteEntry? {
        guard currentNoteIndex < notes.count else { return nil }
        return notes[currentNoteIndex]
    }
    var isComplete: Bool { currentNoteIndex >= notes.count }

    init(song: Song) {
        self.song = song
        self.metronome = Metronome(bpm: song.bpm)
        self.pitchDetector = PitchDetector()
        self.hitJudge = HitJudge(song: song)
    }

    func startPlaying() {
        isPlaying = true
        isPaused = false
        currentNoteIndex = 0
        lastDetectionCorrect = nil
        accumulatedBeforePause = 0
        playStartedAt = Date()
        resetHitState()
    }

    func pausePlaying() {
        guard isPlaying else { return }
        if let started = playStartedAt {
            accumulatedBeforePause += Date().timeIntervalSince(started)
        }
        playStartedAt = nil
        isPlaying = false
        isPaused = true
    }

    func resumePlaying() {
        guard isPaused else { return }
        isPaused = false
        isPlaying = true
        playStartedAt = Date()
    }

    func stopPlaying() {
        isPlaying = false
        isPaused = false
        lastDetectionCorrect = nil
        playStartedAt = nil
        accumulatedBeforePause = 0
        resetHitState()
    }

    /// Clear hit-detection state for a fresh play / replay: notes become
    /// hittable again, combo + tally reset.
    private func resetHitState() {
        hitJudge.reset()
        comboCount = 0
        lastJudgment = nil
    }

    func restart() {
        stopPlaying()
        currentNoteIndex = 0
        startPlaying()
    }

    func checkDetectedNote() {
        guard let currentNote = currentNote,
              let detectedNote = pitchDetector.detectedNote else {
            lastDetectionCorrect = nil
            return
        }

        // Compare solfège (ignore octave for young learners — matching pitch class is enough)
        let correct = detectedNote == currentNote.solfege
        lastDetectionCorrect = correct

        if correct {
            // Flash green and advance
            feedbackFlash = .green
            advanceToNextNote()
        } else {
            feedbackFlash = .red
        }

        // Clear flash after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.feedbackFlash = nil
        }
    }

    func advanceToNextNote() {
        guard currentNoteIndex < notes.count else { return }
        withAnimation(.spring(response: 0.3)) {
            currentNoteIndex += 1
        }
        lastDetectionCorrect = nil

        if isComplete {
            stopPlaying()
        }
    }

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

        // Falling-notes hit detection. Only judge while the game panel is the
        // active mode and playing, so sheet-music taps don't consume notes.
        // Right key is required for a celebration; timing only separates
        // PERFECT from HIT. Visual juice consumes `lastHit`; audio sparkle fires
        // here off the same outcome.
        guard fallingNotesActive, isPlaying else { return }
        let judgment = hitJudge.judge(pitch: pitch, elapsedSeconds: elapsedSeconds, bpm: metronome.bpm)
        applyJudgment(judgment, pitch: pitch)
        if judgment != .miss {
            sampler.playSparkle(base: pitch, comboStep: comboCount - 1, perfect: judgment == .perfect)
        }
    }

    /// Fold a press outcome into combo state, publish the celebration event for
    /// the scene, and log the running right/miss tally — the mashing-vs-learning
    /// curve the playtest protocol reads straight off the console.
    private func applyJudgment(_ judgment: HitJudgment, pitch: Pitch) {
        switch judgment {
        case .perfect, .hit: comboCount += 1
        case .miss: comboCount = 0
        }
        lastJudgment = judgment
        hitEventCounter += 1
        let lane = KeyboardLayout.default.laneIndex(for: pitch) ?? -1
        lastHit = HitEvent(id: hitEventCounter, lane: lane, judgment: judgment, combo: comboCount)
        print("[HitJudge] \(judgment) · right=\(hitJudge.rightTaps) miss=\(hitJudge.missTaps) combo=\(comboCount)")
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

    func toggleNotation() {
        useSolfege.toggle()
    }

    func requestMicPermission() {
        pitchDetector.requestPermission()
    }
}

// MARK: - Hit detection

/// Outcome of a key press judged against the falling-note schedule.
enum HitJudgment: Equatable {
    case perfect   // right key, |Δ| ≤ 250 ms
    case hit       // right key, |Δ| ≤ 600 ms
    case miss      // wrong key, or no note in the window
}

/// A celebration to forward to the falling-notes scene. `id` lets the view
/// detect a genuinely new hit vs a re-render of the same value.
struct HitEvent: Equatable {
    let id: Int
    let lane: Int
    let judgment: HitJudgment
    let combo: Int
}

/// Judges key presses against a song's falling-note schedule — pure timing
/// logic, no rendering. The note→key map is the lesson, so a **wrong key is
/// always a MISS**; timing only separates PERFECT from HIT. Each note is
/// consumable once, so mashing one correct key can't rack up repeat hits —
/// the integrity the playtest's "deliberate right-key" metric depends on.
///
/// Windows are deliberately enormous for ages 5–7 (adult rhythm games run
/// ±30–50 ms). Spec: `docs/superpowers/specs/2026-06-08-hit-event-spec.md`.
///
/// Co-located in this file (rather than its own) because the Xcode project
/// uses manual file references; extract when batching a file add.
final class HitJudge {
    enum Window {
        static let perfectMs = 250.0
        static let hitMs = 600.0
    }

    /// One strike opportunity: a note's ideal hit moment (in beats from t=0)
    /// and the white-key lane it belongs to.
    private struct ScheduledHit {
        let hitBeat: Double
        let lane: Int
    }

    private let layout: KeyboardLayout
    private let hits: [ScheduledHit]
    private var consumed: Set<Int> = []

    /// Right vs missed tap tally for the mashing-vs-learning curve (Mei's
    /// metric). `rightTaps` rises only on a real PERFECT/HIT; `missTaps`
    /// covers wrong-key and mistimed presses alike.
    private(set) var rightTaps = 0
    private(set) var missTaps = 0

    init(song: Song, layout: KeyboardLayout = .default) {
        self.layout = layout
        var cumulativeBeats = 0.0
        var built: [ScheduledHit] = []
        for note in song.notes {
            let hitBeat = cumulativeBeats
            cumulativeBeats += note.duration.beats
            let pitch = Pitch(solfege: note.solfege, octave: note.octave)
            guard let lane = layout.laneIndex(for: pitch) else { continue }
            built.append(ScheduledHit(hitBeat: hitBeat, lane: lane))
        }
        hits = built
    }

    /// Judge a press `elapsedSeconds` into the song at the current `bpm`.
    /// Beats are converted to ms with the live bpm (matching the scene), so
    /// tempo changes stay consistent. Consumes the matched note.
    func judge(pitch: Pitch, elapsedSeconds: TimeInterval, bpm: Int) -> HitJudgment {
        let beatDuration = 60.0 / Double(max(bpm, 30))
        let nowBeats = elapsedSeconds / beatDuration

        guard let lane = layout.laneIndex(for: pitch) else {
            missTaps += 1            // sharp / out of range — no note can match
            return .miss
        }

        var bestIndex: Int?
        var bestDeltaMs = Double.greatestFiniteMagnitude
        for (index, hit) in hits.enumerated()
        where hit.lane == lane && !consumed.contains(index) {
            let deltaMs = abs((hit.hitBeat - nowBeats) * beatDuration) * 1000
            if deltaMs < bestDeltaMs {
                bestDeltaMs = deltaMs
                bestIndex = index
            }
        }

        guard let index = bestIndex, bestDeltaMs <= Window.hitMs else {
            missTaps += 1
            return .miss
        }
        consumed.insert(index)
        rightTaps += 1
        return bestDeltaMs <= Window.perfectMs ? .perfect : .hit
    }

    /// Clear consumption + tally for a fresh play / replay.
    func reset() {
        consumed.removeAll()
        rightTaps = 0
        missTaps = 0
    }
}
