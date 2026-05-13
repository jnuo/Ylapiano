import Foundation
import SwiftUI

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

    func toggleNotation() {
        useSolfege.toggle()
    }

    func requestMicPermission() {
        pitchDetector.requestPermission()
    }
}
