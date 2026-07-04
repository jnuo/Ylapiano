import AVFoundation
import XCTest
@testable import Ylapiano

/// #16 (B11) — result-screen celebration sound + Pim variety pool.
///
/// Guards Khalid's committee bar: celebration-ONLY tiers (1 star warm, never
/// minor/descending-sad), rising Do–Mi–Sol star dings, 3–4 top-tier fanfare
/// variations, mastered levels (peak ≤ -1 dBTP with margin, RMS driven toward
/// -18 dBFS as the LUFS proxy — true K-weighted LUFS stays a subjective
/// device check), and the Pim reaction pool that replaced B12 ("hmm" must
/// never answer a completion).
///
/// `testRenderTierEvidenceForEarReview` also renders the three full tier
/// experiences (dings on the star beat + fanfare) to
/// `~/Downloads/ylapiano-b11-sounds/` for the human ear pass.
@MainActor
final class ResultSoundTests: XCTestCase {

    // MARK: - Star dings

    func testStarDingsRiseDoMiSol() {
        // One warm note per star, pitch RISING across the three pops:
        // Do–Mi–Sol = C5, E5, G5.
        XCTAssertEqual(ResultSoundDesign.starDingMidis, [72, 76, 79])
        let midis = ResultSoundDesign.starDingMidis.map(Int.init)
        XCTAssertEqual(midis, midis.sorted(), "dings must rise with the stars")
        XCTAssertEqual(Set(midis).count, midis.count, "each star gets its own pitch")
        for midi in midis {
            XCTAssertTrue(ResultSoundDesign.majorTriadPitchClasses.contains(midi % 12),
                          "ding \(midi) leaves the C-major triad")
        }
    }

    func testStarBeatMatchesTheStarPopSpacing() {
        // runSequence pops a star every 340 ms; the dings ride that beat.
        XCTAssertEqual(ResultSoundDesign.starBeatMilliseconds, 340)
    }

    // MARK: - Tier → phrase mapping

    func testTierPhraseMappingAndVariationCounts() {
        XCTAssertEqual(ResultSoundDesign.variantCount(stars: 1), 1)
        XCTAssertEqual(ResultSoundDesign.variantCount(stars: 2), 1)
        let topVariants = ResultSoundDesign.variantCount(stars: 3)
        XCTAssertTrue((3...4).contains(topVariants), "top tier needs 3–4 variations, got \(topVariants)")

        // Every tier/variant resolves to a non-empty phrase; out-of-range
        // stars clamp instead of crashing.
        for stars in [0, 1, 2, 3, 4] {
            for variant in 0..<ResultSoundDesign.variantCount(stars: stars) {
                XCTAssertFalse(ResultSoundDesign.fanfare(stars: stars, variant: variant).isEmpty)
            }
        }
        XCTAssertEqual(ResultSoundDesign.fanfare(stars: 0, variant: 0),
                       ResultSoundDesign.fanfare(stars: 1, variant: 0))
        XCTAssertEqual(ResultSoundDesign.fanfare(stars: 9, variant: 0),
                       ResultSoundDesign.fanfare(stars: 3, variant: 0))

        // The tiers are genuinely different phrases, and the top-tier
        // variations differ from each other.
        XCTAssertNotEqual(ResultSoundDesign.fanfare(stars: 1, variant: 0),
                          ResultSoundDesign.fanfare(stars: 2, variant: 0))
        for a in 0..<topVariants {
            for b in (a + 1)..<topVariants {
                XCTAssertNotEqual(ResultSoundDesign.fanfare(stars: 3, variant: a),
                                  ResultSoundDesign.fanfare(stars: 3, variant: b),
                                  "3★ variations \(a) and \(b) are identical")
            }
        }
    }

    func testEveryPhraseStaysInsideTheMajorTriad() {
        // The structural "never sad" guarantee: no phrase can go minor or
        // dissonant because every note is a C/E/G pitch class.
        for stars in 1...3 {
            for variant in 0..<ResultSoundDesign.variantCount(stars: stars) {
                for note in ResultSoundDesign.fanfare(stars: stars, variant: variant) {
                    XCTAssertTrue(
                        ResultSoundDesign.majorTriadPitchClasses.contains(Int(note.midi) % 12),
                        "\(stars)★ v\(variant) note \(note.midi) leaves the C-major triad")
                }
            }
        }
    }

    func testOneStarPhraseIsWarmNeverSad() {
        // 1★ converts a retry, not an exit: it must END UP (rising, hopeful),
        // sit low and soft — audibly gentler than the 3★ flourish.
        let phrase = ResultSoundDesign.fanfare(stars: 1, variant: 0)
        let ordered = phrase.sorted { $0.onsetSeconds < $1.onsetSeconds }
        XCTAssertGreaterThan(Int(ordered.last!.midi), Int(ordered.first!.midi),
                             "1★ phrase must end higher than it starts — never descending-sad")
        // Monotonically non-descending — no drooping contour anywhere.
        for (a, b) in zip(ordered, ordered.dropFirst()) {
            XCTAssertGreaterThanOrEqual(b.midi, a.midi, "1★ phrase dips downward")
        }
        let softest3Star = ResultSoundDesign.threeStarVariations
            .flatMap { $0 }.map(\.velocity).min()!
        XCTAssertLessThan(phrase.map(\.velocity).max()!, softest3Star,
                          "1★ must play softer than any 3★ flourish note")
    }

    // MARK: - Pim reaction pool (replaced B12)

    func testPoolsAreCelebrationOnlyAndNeverHmm() {
        // PimResult1 is "hmm, again!" — contemplative. Every result screen is
        // a completion, so it is in NO pool.
        for stars in [0, 1, 2, 3, 4] {
            let pool = PimReactionPool.clips(forStars: stars)
            XCTAssertFalse(pool.isEmpty)
            XCTAssertFalse(pool.contains(PimReactionPool.contemplativeClip),
                           "\(stars)★ pool contains the contemplative 'hmm' clip")
            XCTAssertTrue(Set(pool).isSubset(of: ["PimResult2", "PimResult3"]))
            XCTAssertEqual(Set(pool).count, pool.count, "duplicate clips skew the draw")
        }
        // 1★ stays warm-and-gentle: clap only, no jump-cheer overclaiming.
        XCTAssertEqual(PimReactionPool.clips(forStars: 1), ["PimResult2"])
        // 2★/3★ mix clap + jump-cheer so replays vary; 3★ includes the cheer.
        XCTAssertEqual(Set(PimReactionPool.clips(forStars: 2)), ["PimResult2", "PimResult3"])
        XCTAssertTrue(PimReactionPool.clips(forStars: 3).contains("PimResult3"))
    }

    func testRandomDrawStaysInPoolAndActuallyVaries() {
        var rng = SplitMix64(seed: 0xB11)
        for stars in 1...3 {
            let pool = Set(PimReactionPool.clips(forStars: stars))
            var seen: Set<String> = []
            for _ in 0..<200 {
                seen.insert(PimReactionPool.clip(forStars: stars, using: &rng))
            }
            XCTAssertTrue(seen.isSubset(of: pool), "\(stars)★ drew outside its pool")
            XCTAssertEqual(seen, pool, "\(stars)★ never drew part of its pool in 200 tries")
        }
        // All bundled pool clips actually exist in the app bundle.
        for clip in ["PimResult2", "PimResult3"] {
            XCTAssertNotNil(Bundle(for: PianoSampler.self).url(forResource: clip, withExtension: "mp4"),
                            "\(clip).mp4 missing from bundle")
        }
    }

    // MARK: - Rendered buffers: format + mastering

    func testRenderedBuffersAreMonoAt48kWithMasteredLevels() {
        var buffers: [(String, AVAudioPCMBuffer)] = []
        for index in 0..<3 {
            buffers.append(("ding-\(index)", PianoSampler.renderStarDing(index: index)))
        }
        for stars in 1...3 {
            for variant in 0..<ResultSoundDesign.variantCount(stars: stars) {
                let phrase = ResultSoundDesign.fanfare(stars: stars, variant: variant)
                buffers.append(("fanfare-\(stars)-v\(variant)", PianoSampler.renderResultPhrase(phrase)))
            }
        }

        // -1.2 dBFS sample-peak bar — our ceiling is -1.5 dBFS, and sampled
        // piano at 48 kHz has well under 0.3 dB inter-sample overshoot, so
        // passing here means true peak stays under the -1 dBTP spec.
        let peakBar = Float(pow(10.0, -1.2 / 20.0))
        for (name, buffer) in buffers {
            XCTAssertEqual(buffer.format.sampleRate, 48_000, "\(name) sample rate")
            XCTAssertEqual(buffer.format.channelCount, 1, "\(name) must be mono-first")
            XCTAssertGreaterThan(buffer.frameLength, 0, "\(name) is empty")

            let peak = Self.peak(of: buffer)
            XCTAssertGreaterThan(peak, 0.05, "\(name) rendered (near-)silent")
            XCTAssertLessThanOrEqual(peak, peakBar,
                                     "\(name) peak \(peak) breaks the -1 dBTP bar")

            // Active-region RMS: driven toward -18 dBFS (the LUFS proxy); the
            // peak ceiling may pull it a few dB under target, never over.
            let rms = 20 * log10(Double(Self.activeRMS(of: buffer)))
            XCTAssertLessThanOrEqual(rms, -16.0, "\(name) RMS \(rms) dBFS is hotter than target")
            XCTAssertGreaterThanOrEqual(rms, -26.0, "\(name) RMS \(rms) dBFS is too quiet to survive a bottom speaker at 30%")
        }
    }

    // MARK: - Wiring contracts (greppable guards, PimIdleTests pattern)

    func testResultScreenWiresDingsAndFanfare() throws {
        let source = try Self.appSource("Views/PlayerScreen.swift")
        XCTAssertTrue(source.contains("sampler.playStarDing(i - 1)"),
                      "star pops must fire their ding")
        XCTAssertTrue(source.contains("sampler.playResultFanfare(stars: stars)"),
                      "the tier fanfare must fire after the last star")
        XCTAssertTrue(source.contains("PimReactionPool.clips(forStars: stars)"),
                      "the reward clip must come from the variety pool")
    }

    func testHomeScreenKeepsItsSilentLane() throws {
        // B27's lane: no celebration sound on the home screen.
        for file in ["Views/HomeScreen.swift", "Views/PimIdleView.swift"] {
            let source = try Self.appSource(file)
            XCTAssertFalse(source.contains("playStarDing"), "\(file) plays result sound")
            XCTAssertFalse(source.contains("playResultFanfare"), "\(file) plays result sound")
        }
    }

    // MARK: - Ear-review evidence (B25 harness pattern)

    /// Renders the three full tier experiences — dings on the star beat, the
    /// tier fanfare one beat after the last star — plus every 3★ variation,
    /// to `~/Downloads/ylapiano-b11-sounds/` (override: `B11_SOUNDS_OUT`).
    func testRenderTierEvidenceForEarReview() throws {
        let dir = Self.outputDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var jobs: [(file: String, stars: Int, variant: Int)] = [
            ("result-1-star.m4a", 1, 0),
            ("result-2-star.m4a", 2, 0),
        ]
        for variant in 0..<ResultSoundDesign.variantCount(stars: 3) {
            jobs.append(("result-3-star-v\(variant + 1).m4a", 3, variant))
        }

        for job in jobs {
            let mix = Self.renderTierExperience(stars: job.stars, variant: job.variant)
            XCTAssertGreaterThan(Self.peak(of: mix), 0.05, "\(job.file) rendered silent")
            let url = dir.appendingPathComponent(job.file)
            try? FileManager.default.removeItem(at: url)
            try {
                let file = try AVAudioFile(
                    forWriting: url,
                    settings: [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: 48_000.0,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderBitRateKey: 128_000,
                    ],
                    commonFormat: .pcmFormatFloat32,
                    interleaved: false
                )
                try file.write(from: mix)
            }()
        }

        let readme = """
        B11 (#16) result-screen sound — ear review
        ==========================================
        Each file is the FULL result-screen audio for its tier: one warm piano
        ding per star (rising Do–Mi–Sol, one every 340 ms — the star-pop beat),
        then the tier fanfare one beat after the last star. All sound is the
        app's own sampled piano (Upright Piano KW, C major), mastered to
        RMS ≈ -18 dBFS with peak ≤ -1.5 dBFS.

        result-1-star.m4a     — warm, low, soft. Must feel like a hug, never sad.
        result-2-star.m4a     — brighter, quicker.
        result-3-star-v1..v4  — full flourish; the app picks one at random.

        Device checklist (subjective): intelligible on the bottom speaker at
        30% volume; LUFS target -18 verified by ear on device.
        """
        try readme.write(to: dir.appendingPathComponent("README.txt"),
                         atomically: true, encoding: .utf8)
        print("B11SOUNDS | wrote \(jobs.count) files + README.txt → \(dir.path)")
    }

    // MARK: - Helpers

    /// `~/Downloads/ylapiano-b11-sounds` on the host Mac (EarCheck pattern).
    private static var outputDir: URL {
        if let override = ProcessInfo.processInfo.environment["B11_SOUNDS_OUT"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let comps = URL(fileURLWithPath: #filePath).pathComponents
        if comps.count > 2, comps[1] == "Users" {
            return URL(fileURLWithPath: "/Users/\(comps[2])/Downloads/ylapiano-b11-sounds",
                       isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Downloads/ylapiano-b11-sounds", isDirectory: true)
    }

    /// The result screen's audio timeline: ding i at i·beat, fanfare one beat
    /// after the last star — exactly `runSequence`'s spacing.
    private static func renderTierExperience(stars: Int, variant: Int) -> AVAudioPCMBuffer {
        let sampleRate = 48_000.0
        let beat = Double(ResultSoundDesign.starBeatMilliseconds) / 1000.0
        var pieces: [(onset: Double, buffer: AVAudioPCMBuffer)] = []
        for i in 0..<stars {
            pieces.append((Double(i) * beat, PianoSampler.renderStarDing(index: i)))
        }
        let phrase = ResultSoundDesign.fanfare(stars: stars, variant: variant)
        pieces.append((Double(stars) * beat, PianoSampler.renderResultPhrase(phrase)))

        let totalFrames = pieces.map { Int(($0.onset * sampleRate).rounded()) + Int($0.buffer.frameLength) }.max()!
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let mix = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames))!
        mix.frameLength = AVAudioFrameCount(totalFrames)
        let out = mix.floatChannelData![0]
        out.update(repeating: 0, count: totalFrames)
        for piece in pieces {
            let onset = Int((piece.onset * sampleRate).rounded())
            let src = piece.buffer.floatChannelData![0]
            for i in 0..<Int(piece.buffer.frameLength) { out[onset + i] += src[i] }
        }
        // Overlapping pre-mastered pieces can sum hot — normalize DOWN only,
        // keeping the evidence inside the same -1.5 dBFS ceiling.
        let peak = Self.peak(of: mix)
        let ceiling = Float(pow(10.0, -1.5 / 20.0))
        if peak > ceiling {
            let scale = ceiling / peak
            for i in 0..<totalFrames { out[i] *= scale }
        }
        return mix
    }

    private static func peak(of buffer: AVAudioPCMBuffer) -> Float {
        let data = buffer.floatChannelData![0]
        var peak: Float = 0
        for i in 0..<Int(buffer.frameLength) { peak = max(peak, abs(data[i])) }
        return peak
    }

    /// RMS over the active region (first→last sample above -60 dBFS) —
    /// independent re-measurement of what the mastering targets.
    private static func activeRMS(of buffer: AVAudioPCMBuffer) -> Float {
        let data = buffer.floatChannelData![0]
        let n = Int(buffer.frameLength)
        var first = -1, last = -1
        for i in 0..<n where abs(data[i]) > 0.001 {
            if first < 0 { first = i }
            last = i
        }
        guard first >= 0 else { return 0 }
        var sum = 0.0
        for i in first...last {
            let s = Double(data[i])
            sum += s * s
        }
        return Float((sum / Double(last - first + 1)).squareRoot())
    }

    /// Repo root → `Ylapiano/<relative>` source text (PimIdleTests pattern).
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func appSource(_ relative: String) throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent("Ylapiano").appendingPathComponent(relative),
            encoding: .utf8
        )
    }
}

/// Deterministic RNG for the pool-draw tests.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
