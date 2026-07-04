import AVFoundation   // AVAudioFramePosition (CountIn) — no session use here
import Foundation
import Observation

/// The song's tempo knob. BPM is the single value the rest of the pipeline
/// reads — the falling-notes scene, HitJudge, abcjs, and the count-in all
/// convert beats → seconds through it.
///
/// **B6 (#14): this owns NO audio and NO session anymore.** The old
/// free-running `Timer` + system-sound tick was replaced by
/// `FallingNotesScene`'s beat tocks (fired off the same clock as the blocks,
/// through the shared engine), and its private `AVAudioSession` setup — the
/// record-capable-category mic legacy B5 (#27) found — is folded into
/// `AudioSession.configurePlayback()`, the app's one session owner.
@Observable
final class Metronome {
    var bpm: Int

    init(bpm: Int = 100) {
        self.bpm = bpm
        AudioSession.configurePlayback()
    }
}

/// Count-in scheduling math — pure frame arithmetic, unit-tested without an
/// engine (`CountInTests`).
///
/// The count-in IS the song's lead-in: `beats` equals `HitJudge.leadInBeats`
/// (4 beats = two bars of 2/4), so the overlay's 3-2-1-Go spans exactly the
/// run-up the falling notes are already shifted by and the last count beat
/// hands off to beat 0 of the song.
enum CountIn {
    /// Beats in the count-in. Must equal `HitJudge.leadInBeats` — pinned by
    /// `CountInTests.testCountInBeatsMatchTheLeadIn`.
    static let beats = 4

    /// Sample-frame offset of each count-in tock relative to the first one.
    /// BPM clamps at 30, the same floor as the scene and `HitJudge`.
    static func frameOffsets(bpm: Int, sampleRate: Double) -> [AVAudioFramePosition] {
        let beatFrames = AVAudioFramePosition((60.0 / Double(max(bpm, 30))) * sampleRate)
        return (0..<beats).map { AVAudioFramePosition($0) * beatFrames }
    }
}
