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

    /// End-of-song result. `songFinished` drives the result overlay; the rest
    /// is the frozen score to show (no numbers on screen — stars + a face).
    var songFinished = false
    private(set) var resultStars = 0
    private(set) var resultRight = 0
    private(set) var resultTotal = 0
    /// Notes never landed this play — the "practice these" set the result screen
    /// shows as gentle key chips. Empty on a clean run (no dead-end screen).
    private(set) var resultMissed: [Solfege] = []

    // MARK: - Mastery ladder

    /// Which rung of the single-song ladder the player is on (0-based). Same
    /// song every rung; tempo + guidance + timing window scale. Held in memory
    /// for the sitting — persisting best-rung across launches is backlog.
    private(set) var rungIndex = 0
    var currentRung: Rung { MasteryLadder.rungs[rungIndex] }
    var isTopRung: Bool { rungIndex >= MasteryLadder.rungs.count - 1 }
    /// True only at the result screen when the player earned the climb: a clean
    /// 3-star run with a rung still above. Climbing is always the player's choice.
    var canClimb: Bool { songFinished && resultStars >= 3 && !isTopRung }
    /// What the next rung changes, for the climb button. Losing the glow is the
    /// headline ("Lights off!"); otherwise it's always faster.
    var climbLabel: String {
        guard !isTopRung else { return "" }
        let next = MasteryLadder.rungs[rungIndex + 1]
        if next.guidance == .none, currentRung.guidance != .none { return "Lights off!" }
        return "Faster!"
    }

    /// The key the keyboard should glow as "play this next", driven off the
    /// SAME shared clock as the falling blocks (`elapsedSeconds` + lead-in), so
    /// the glow can never drift from the bars. `nil` when guidance is off
    /// (rung 4) or nothing is due. Refreshed by `guidanceTimer` while playing.
    private(set) var guidanceNote: NoteEntry?
    private var guidanceTimer: Timer?

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

    /// abcjs reports note-change indices over SOUNDING notes only (it skips
    /// rests); map one back to an index into the full `notes` array.
    func entryIndex(forSoundingIndex soundingIndex: Int) -> Int {
        var sounding = -1
        for (index, note) in notes.enumerated() where !note.isRest {
            sounding += 1
            if sounding == soundingIndex { return index }
        }
        return notes.count
    }

    init(song: Song) {
        self.song = song
        self.metronome = Metronome(bpm: song.bpm)
        self.pitchDetector = PitchDetector()
        self.hitJudge = HitJudge(song: song)
        applyRung()   // open on rung 1's tempo / guidance / windows
    }

    /// Push the current rung's three knobs into the live systems: tempo →
    /// metronome (and thence the scene + sheet), guidance → keyboard glow,
    /// timing → hit windows. Called at init and before every fresh play, never
    /// mid-song.
    private func applyRung() {
        let rung = currentRung
        metronome.bpm = rung.bpm
        guidedMode = rung.guidance != .none
        hitJudge.setWindows(hitMs: rung.hitMs, perfectMs: rung.perfectMs)
    }

    func startPlaying() {
        applyRung()
        isPlaying = true
        isPaused = false
        currentNoteIndex = 0
        lastDetectionCorrect = nil
        accumulatedBeforePause = 0
        playStartedAt = Date()
        resetHitState()
        startGuidanceTimer()
    }

    func pausePlaying() {
        guard isPlaying else { return }
        if let started = playStartedAt {
            accumulatedBeforePause += Date().timeIntervalSince(started)
        }
        playStartedAt = nil
        isPlaying = false
        isPaused = true
        stopGuidanceTimer()
    }

    func resumePlaying() {
        guard isPaused else { return }
        isPaused = false
        isPlaying = true
        playStartedAt = Date()
        startGuidanceTimer()
    }

    func stopPlaying() {
        isPlaying = false
        isPaused = false
        lastDetectionCorrect = nil
        playStartedAt = nil
        accumulatedBeforePause = 0
        resetHitState()
        stopGuidanceTimer()
    }

    /// Clear hit-detection state for a fresh play / replay: notes become
    /// hittable again, combo + tally reset.
    private func resetHitState() {
        hitJudge.reset()
        comboCount = 0
        lastJudgment = nil
        songFinished = false
    }

    /// The song's last bar has fallen. Freeze the clock (so the metronome
    /// stops), snapshot the score, and raise the result overlay. Called by the
    /// falling-notes scene from its own clock — no dependency on abcjs.
    func finishSong() {
        guard isPlaying, !songFinished else { return }
        if let started = playStartedAt {
            accumulatedBeforePause += Date().timeIntervalSince(started)
        }
        playStartedAt = nil
        isPlaying = false
        stopGuidanceTimer()

        resultTotal = hitJudge.totalNotes
        resultRight = hitJudge.rightTaps
        resultStars = Self.stars(right: resultRight, total: resultTotal)
        resultMissed = hitJudge.missedSolfege()   // snapshot before reset() clears it
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            songFinished = true
        }
    }

    /// Replay from the result screen — same rung, beat your best.
    func replaySong() {
        songFinished = false
        restart()
    }

    /// Take the next rung up (offered only after a clean 3-star run). The
    /// player chose this — never automatic, never a down-rung punishment.
    func climbRung() {
        guard canClimb else { return }
        rungIndex += 1
        songFinished = false
        restart()
    }

    // MARK: - Synced guidance (keyboard glow)

    /// Sample the shared clock ~20×/s and light the upcoming target key. Not a
    /// second timebase — it reads the same `elapsedSeconds` the scene does, so
    /// glow and bars stay locked. Off for rung 4 (no guidance) — then we never
    /// arm the timer and `guidanceNote` stays nil.
    private func startGuidanceTimer() {
        stopGuidanceTimer()
        guard currentRung.guidance != .none else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            // Fires on the main run loop; assert that so the @Observable write
            // is main-actor isolated (SwiftUI observation requires it).
            MainActor.assumeIsolated {
                guard let self else { return }
                self.guidanceNote = self.computeGuidanceNote()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        guidanceTimer = timer
    }

    private func stopGuidanceTimer() {
        guidanceTimer?.invalidate()
        guidanceTimer = nil
        guidanceNote = nil
    }

    /// The note to glow right now: the earliest one whose target moment is
    /// approaching (lit ~1.2 beats early so a hand can move) and hasn't slipped
    /// past its hit window yet. Same beat math as `HitJudge`/the scene.
    private func computeGuidanceNote() -> NoteEntry? {
        guard isPlaying, currentRung.guidance != .none else { return nil }
        let beatDuration = 60.0 / Double(max(metronome.bpm, 30))
        let nowBeats = elapsedSeconds / beatDuration
        let windowBeats = (hitJudge.hitWindowMs / 1000.0) / beatDuration
        let leadGlowBeats = 1.2   // how early the key lights before its moment

        var cumulative = 0.0
        for note in notes {
            let dueBeat = cumulative + HitJudge.leadInBeats
            cumulative += note.duration.beats
            if note.isRest { continue }   // nothing to guide during a rest
            if nowBeats >= dueBeat - leadGlowBeats && nowBeats <= dueBeat + windowBeats {
                return note   // notes are in time order → first match is the earliest active
            }
        }
        return nil
    }

    /// Stars from accuracy. Always at least 1 — we never show a kid zero.
    private static func stars(right: Int, total: Int) -> Int {
        guard total > 0 else { return 1 }
        let ratio = Double(right) / Double(total)
        if ratio >= 0.8 { return 3 }
        if ratio >= 0.5 { return 2 }
        return 1
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
            // Rests expect no input — never park the cursor on one.
            while currentNoteIndex < notes.count && notes[currentNoteIndex].isRest {
                currentNoteIndex += 1
            }
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

// MARK: - Mastery ladder

/// How strongly the keyboard's target-key glow guides the player on a rung.
/// The falling block always shows the note; this is the *extra* hand-holding
/// (light up the key you're about to need), scaled down as mastery grows.
enum Guidance {
    case full     // bright glow — the 5yo floor
    case fading   // dim glow — training wheels coming off
    case none     // block only — adult ceiling

    /// Glow opacity for `PianoKeyboardView`, or `nil` to suppress the glow
    /// entirely (the view is fed no `expectedNote`).
    var glowOpacity: Double? {
        switch self {
        case .full: return 0.35
        case .fading: return 0.16
        case .none: return nil
        }
    }
}

/// One rung of the single-song mastery ladder. The **song is constant**; a
/// rung scales three knobs — tempo, guidance, and timing strictness — so the
/// same notes serve a 5yo (rung 1) and an adult (rung 4). Numbers from
/// `docs/superpowers/specs/2026-06-09-single-song-mastery-ladder.md`; tune in
/// playtest. Co-located with `HitJudge` (which consumes the windows) so adding
/// a rung never touches the manual Xcode file references.
struct Rung {
    let name: String
    let bpm: Int
    let guidance: Guidance
    let hitMs: Double       // HIT window (right key, looser timing)
    let perfectMs: Double   // PERFECT window (right key, tight timing)
}

enum MasteryLadder {
    /// The four rungs, slow→fast / guided→bare / forgiving→precise.
    static let rungs: [Rung] = [
        Rung(name: "Learn the keys", bpm: 50,  guidance: .full,   hitMs: 600, perfectMs: 250),
        Rung(name: "Find the beat",  bpm: 70,  guidance: .full,   hitMs: 450, perfectMs: 200),
        Rung(name: "Play it",        bpm: 96,  guidance: .fading, hitMs: 300, perfectMs: 150),
        Rung(name: "Master it",      bpm: 120, guidance: .none,   hitMs: 150, perfectMs: 60),
    ]
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
    /// Live timing windows (ms). Default to rung 1's forgiving numbers; the
    /// mastery ladder narrows them per rung via `setWindows`. Instance state
    /// (not the old `static`) so a rung change is a property set, not a rebuild.
    private(set) var hitWindowMs = 600.0
    private(set) var perfectWindowMs = 250.0

    /// Tighten / loosen the timing windows for a rung. Called before a fresh
    /// play — never mid-song, so an in-flight judgment can't straddle two windows.
    func setWindows(hitMs: Double, perfectMs: Double) {
        hitWindowMs = hitMs
        perfectWindowMs = perfectMs
    }

    /// Beats of run-up before note one is due, so the first bar has fall-time
    /// (you were always late because note one was due the instant play began).
    /// 4 beats = ~two bars in 2/4 — the metronome counts you in during it.
    /// Shared with `FallingNotesScene` so blocks + judging agree.
    static let leadInBeats: Double = 4

    /// Total judgeable notes in the song — the denominator for the end score.
    var totalNotes: Int { hits.count }

    /// One strike opportunity: a note's ideal hit moment (in beats from t=0)
    /// and the white-key lane it belongs to.
    private struct ScheduledHit {
        let hitBeat: Double
        let lane: Int
        let solfege: Solfege   // which note this was — drives the near-miss display
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
            if note.isRest { continue }   // rests take time but expect no press
            let pitch = Pitch(solfege: note.solfege, octave: note.octave)
            guard let lane = layout.laneIndex(for: pitch) else { continue }
            built.append(ScheduledHit(hitBeat: hitBeat, lane: lane, solfege: note.solfege))
        }
        hits = built
    }

    /// Distinct solfège of notes never landed this play-through — the "what to
    /// practice" set for the near-miss display. Order-preserving (first-missed
    /// first) and de-duplicated so a song that repeats Sol shows it once.
    func missedSolfege() -> [Solfege] {
        var seen: Set<Solfege> = []
        var result: [Solfege] = []
        for (index, hit) in hits.enumerated() where !consumed.contains(index) {
            if seen.insert(hit.solfege).inserted { result.append(hit.solfege) }
        }
        return result
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
            let deltaMs = abs((hit.hitBeat + Self.leadInBeats - nowBeats) * beatDuration) * 1000
            if deltaMs < bestDeltaMs {
                bestDeltaMs = deltaMs
                bestIndex = index
            }
        }

        guard let index = bestIndex, bestDeltaMs <= hitWindowMs else {
            missTaps += 1
            return .miss
        }
        consumed.insert(index)
        rightTaps += 1
        return bestDeltaMs <= perfectWindowMs ? .perfect : .hit
    }

    /// Clear consumption + tally for a fresh play / replay.
    func reset() {
        consumed.removeAll()
        rightTaps = 0
        missTaps = 0
    }
}
