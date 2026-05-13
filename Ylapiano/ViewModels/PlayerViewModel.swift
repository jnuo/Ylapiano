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
    }

    func startPlaying() {
        isPlaying = true
        isPaused = false
        currentNoteIndex = 0
        lastDetectionCorrect = nil
        accumulatedBeforePause = 0
        playStartedAt = Date()
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
