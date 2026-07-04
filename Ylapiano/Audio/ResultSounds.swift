import AVFoundation

/// #16 (B11) — result-screen celebration sound: star dings + tier fanfare.
///
/// Every sound here is the SAMPLED PIANO ITSELF (B23's Upright Piano KW SF2,
/// rendered through `PianoSampler.renderTone`, the exact tone path the app
/// plays live) — so the celebration is sonically coherent with the instrument
/// the kid just played, with zero licensing and zero new bundled assets. The
/// sparkle celesta (hit juice) is untouched; this is a separate, end-of-song
/// layer.
///
/// Khalid's committee bar (issue #16): CELEBRATION-ONLY tiers. 1 star must
/// sound WARM — never minor, never descending-sad — because sad audio turns a
/// retry into an app-exit at age 5. Everything below stays inside the C-major
/// TRIAD (pitch classes C/E/G): a phrase built only from Do–Mi–Sol cannot
/// sound sad or clash with itself. `ResultSoundTests` enforces that.
///
/// Loudness: phrases are rendered OFFLINE at first use (B25's manual-render
/// seam — dependable levels, unlike live AU velocity layers), then mastered in
/// `masterResultBuffer`: active-region RMS driven toward -18 dBFS (engineering
/// proxy for the -18 LUFS target; true K-weighted LUFS is the subjective
/// device check) with a hard peak ceiling of -1.5 dBFS, comfortably under the
/// -1 dBTP bar. Tests parse the rendered buffers and assert both.
struct ResultPhraseNote: Equatable {
    let midi: UInt8
    let velocity: UInt8
    let onsetSeconds: Double
}

enum ResultSoundDesign {
    /// One warm piano note per star as it pops — pitch RISES Do–Mi–Sol
    /// (C5, E5, G5) across the three stars, mirroring the visual climb.
    static let starDingMidis: [UInt8] = [72, 76, 79]

    /// Star-pop spacing in `SongResultView.runSequence` — the dings ride
    /// exactly this beat so sound and pop land together.
    static let starBeatMilliseconds = 340

    /// The C-major triad pitch classes (C, E, G). EVERY note in every ding
    /// and fanfare lives here — the structural guarantee that no tier can
    /// sound minor/sad (Khalid: 1 star must never read as failure).
    static let majorTriadPitchClasses: Set<Int> = [0, 4, 7]

    /// Fanfare variations per tier. Tiers 1 and 2 are single designed
    /// phrases; the top tier gets 4 melodic variations picked at random so a
    /// kid replaying for 3 stars keeps hearing a fresh flourish.
    static func variantCount(stars: Int) -> Int {
        clampedTier(stars) >= 3 ? 4 : 1
    }

    /// Tier → phrase mapping. All phrases end on (or hold) a HIGHER note than
    /// they start — rising = hopeful, per the celebration-only bar.
    ///
    /// - 1★: warm, low, soft — a gentle rolled C-major arpeggio (C4→C5).
    /// - 2★: brighter — quicker arpeggio, one octave-up accent (→E5).
    /// - 3★: full flourish — fast run/bounce ending in a high chord.
    static func fanfare(stars: Int, variant: Int) -> [ResultPhraseNote] {
        let tier = clampedTier(stars)
        switch tier {
        case 1:
            // Warm hug: slow, soft, low, rising. Major, never sad.
            return [
                note(60, 58, 0.00),   // C4
                note(64, 56, 0.28),   // E4
                note(67, 58, 0.56),   // G4
                note(72, 54, 0.92),   // C5 — lands UP, gently
            ]
        case 2:
            // Brighter: same shape, quicker, with an octave-up accent.
            return [
                note(60, 72, 0.00),   // C4
                note(64, 72, 0.17),   // E4
                note(67, 74, 0.34),   // G4
                note(72, 78, 0.51),   // C5
                note(76, 80, 0.85),   // E5 accent
            ]
        default:
            return threeStarVariations[
                ((variant % threeStarVariations.count) + threeStarVariations.count)
                    % threeStarVariations.count]
        }
    }

    /// The 4 top-tier flourishes. Same DNA (C-major triad, rising, chord
    /// finish), different melodic shapes.
    static let threeStarVariations: [[ResultPhraseNote]] = [
        // V1 — straight run up the triad, two octaves, chord finish.
        [
            note(60, 84, 0.00), note(64, 85, 0.12), note(67, 86, 0.24),
            note(72, 88, 0.36), note(76, 90, 0.48), note(79, 92, 0.60),
            note(84, 95, 0.72),
            note(72, 88, 1.00), note(76, 88, 1.00), note(79, 88, 1.00), note(84, 92, 1.00),
        ],
        // V2 — herald fanfare: pickup from Sol, two chord hits ("ta-da!").
        [
            note(67, 80, 0.00), note(72, 84, 0.15), note(76, 88, 0.30), note(79, 92, 0.45),
            note(72, 84, 0.75), note(76, 84, 0.75), note(79, 86, 0.75),
            note(76, 90, 1.05), note(79, 92, 1.05), note(84, 95, 1.05),
        ],
        // V3 — sparkle bounce: leaping around the triad, top-C finish.
        [
            note(72, 85, 0.00), note(67, 75, 0.12), note(76, 85, 0.24),
            note(72, 78, 0.36), note(79, 90, 0.48), note(76, 82, 0.60),
            note(84, 95, 0.78),
            note(79, 88, 1.10), note(84, 90, 1.10), note(88, 92, 1.10),
        ],
        // V4 — big ta-daa: grace dyad, climb, one broad final chord.
        [
            note(72, 84, 0.00), note(76, 84, 0.00),
            note(79, 88, 0.14), note(84, 92, 0.28),
            note(60, 86, 0.62), note(67, 86, 0.62), note(72, 88, 0.62),
            note(76, 90, 0.62), note(79, 90, 0.62), note(84, 94, 0.62),
        ],
    ]

    static func clampedTier(_ stars: Int) -> Int { min(max(stars, 1), 3) }

    private static func note(_ midi: UInt8, _ velocity: UInt8, _ onset: Double) -> ResultPhraseNote {
        ResultPhraseNote(midi: midi, velocity: velocity, onsetSeconds: onset)
    }
}

// MARK: - Pim reaction pool (the variety pool that replaced B12)

/// #16 (B11) — per-tier RANDOM pool over the 3 bundled `PimResult*.mp4`
/// reaction clips, replacing the fixed stars→clip mapping.
///
/// Clip character (see `PimIdleView` header): PimResult1 = "hmm, again!"
/// (contemplative), PimResult2 = clap, PimResult3 = jump-cheer.
///
/// "Hmm" is DROPPED from every pool: the result screen only ever shows a
/// completion (stars never drop below 1), and the celebration-only bar says a
/// contemplative reaction must not answer a finished song — there is no
/// neutral moment on this screen to give it. It stays bundled for a future
/// neutral surface (e.g. a mid-song pause), unused today.
enum PimReactionPool {
    /// "hmm, again!" — must never play on a celebration.
    static let contemplativeClip = "PimResult1"

    /// Celebration-appropriate clips per tier. 1★ stays warm-and-gentle
    /// (clap only — a jump-cheer on 1 star would read as mockery to a
    /// grown-up and noise to a kid); 2★ and 3★ mix clap + jump-cheer for
    /// variety, so replays don't feel canned.
    static func clips(forStars stars: Int) -> [String] {
        switch ResultSoundDesign.clampedTier(stars) {
        case 1: return ["PimResult2"]
        case 2: return ["PimResult2", "PimResult3"]
        default: return ["PimResult3", "PimResult2"]
        }
    }

    /// Seedable pick for tests.
    static func clip<G: RandomNumberGenerator>(forStars stars: Int, using generator: inout G) -> String {
        clips(forStars: stars).randomElement(using: &generator)!
    }

    static func clip(forStars stars: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        return clip(forStars: stars, using: &generator)
    }
}

// MARK: - Offline rendering + mastering (B25 seam)

extension PianoSampler {
    /// Mastering targets (see the header). RMS is measured over the ACTIVE
    /// region (first→last sample above -60 dBFS) so decay tails don't dilute
    /// the reading.
    static let resultTargetRMSdBFS = -18.0
    static let resultPeakCeilingdBFS = -1.5

    /// One star ding: a single sampled-piano note, trimmed to a short ding
    /// (fade-out, no click) and mastered. Index 0/1/2 → Do/Mi/Sol.
    static func renderStarDing(index: Int) -> AVAudioPCMBuffer {
        let midis = ResultSoundDesign.starDingMidis
        let midi = midis[min(max(index, 0), midis.count - 1)]
        let tone = renderTone(pitch: Pitch(midi: midi), velocity: 78)
        let ding = trimmed(tone, seconds: 0.9, fadeSeconds: 0.15)
        masterResultBuffer(ding)
        return ding
    }

    /// Mix a fanfare phrase: each note rendered through the sampled piano at
    /// its velocity, added at its onset, then mastered. Tones ring into each
    /// other like a real piano with the pedal down — that IS the flourish.
    static func renderResultPhrase(_ phrase: [ResultPhraseNote]) -> AVAudioPCMBuffer {
        precondition(!phrase.isEmpty, "empty result phrase")
        let sampleRate = 48_000.0
        var tones: [String: AVAudioPCMBuffer] = [:]
        for n in phrase {
            let key = "\(n.midi)-\(n.velocity)"
            if tones[key] == nil {
                tones[key] = renderTone(pitch: Pitch(midi: n.midi), velocity: n.velocity)
            }
        }
        let toneFrames = Int(tones.values.map { Int($0.frameLength) }.max() ?? 0)
        let lastOnset = phrase.map(\.onsetSeconds).max() ?? 0
        let totalFrames = Int((lastOnset * sampleRate).rounded(.up)) + toneFrames
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let mix = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames))!
        mix.frameLength = AVAudioFrameCount(totalFrames)
        let out = mix.floatChannelData![0]
        out.update(repeating: 0, count: totalFrames)

        for n in phrase {
            guard let tone = tones["\(n.midi)-\(n.velocity)"] else { continue }
            let onset = Int((n.onsetSeconds * sampleRate).rounded())
            let src = tone.floatChannelData![0]
            let count = min(Int(tone.frameLength), totalFrames - onset)
            for i in 0..<max(count, 0) { out[onset + i] += src[i] }
        }
        masterResultBuffer(mix)
        return mix
    }

    /// Master a rendered buffer in place: gain the active-region RMS toward
    /// -18 dBFS, clamped so the sample peak never exceeds -1.5 dBFS (margin
    /// under the -1 dBTP bar — sampled-piano content at 48 kHz has well under
    /// 0.5 dB of inter-sample overshoot). Never gains a silent buffer.
    static func masterResultBuffer(_ buffer: AVAudioPCMBuffer) {
        let data = buffer.floatChannelData![0]
        let n = Int(buffer.frameLength)
        let activeFloor: Float = 0.001   // -60 dBFS
        var peak: Float = 0
        var first = -1, last = -1
        for i in 0..<n {
            let a = abs(data[i])
            if a > peak { peak = a }
            if a > activeFloor {
                if first < 0 { first = i }
                last = i
            }
        }
        guard first >= 0, peak > 0 else { return }
        var sumSquares = 0.0
        for i in first...last {
            let s = Double(data[i])
            sumSquares += s * s
        }
        let rms = (sumSquares / Double(last - first + 1)).squareRoot()
        let targetRMS = pow(10.0, resultTargetRMSdBFS / 20.0)
        let ceiling = Float(pow(10.0, resultPeakCeilingdBFS / 20.0))
        let gain = min(Float(targetRMS / rms), ceiling / peak)
        for i in 0..<n { data[i] *= gain }
    }

    /// First `seconds` of `buffer` with a linear fade over the final
    /// `fadeSeconds` — turns a ringing tone into a clean short ding.
    private static func trimmed(
        _ buffer: AVAudioPCMBuffer, seconds: Double, fadeSeconds: Double
    ) -> AVAudioPCMBuffer {
        let sampleRate = buffer.format.sampleRate
        let frames = min(Int(seconds * sampleRate), Int(buffer.frameLength))
        let format = buffer.format
        let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        out.frameLength = AVAudioFrameCount(frames)
        let src = buffer.floatChannelData![0]
        let dst = out.floatChannelData![0]
        dst.update(from: src, count: frames)
        let fadeFrames = min(Int(fadeSeconds * sampleRate), frames)
        for i in 0..<fadeFrames {
            let gain = Float(fadeFrames - i) / Float(fadeFrames)
            dst[frames - fadeFrames + i] *= gain
        }
        return out
    }
}
