import AVFoundation
import XCTest

@testable import Ylapiano

/// B23 (#34) — the sampled piano that retired the synth placeholder.
///
/// Everything here renders OFFLINE through the same `AVAudioUnitSampler` +
/// bundled SoundFont the app plays live (via `PianoSampler.renderTone` or a
/// local manual-rendering engine loading `PianoSampler.soundFontURL`), so the
/// suite is deterministic on a simulator — no speakers, no timing flake.
///
/// Khalid's quality gate, the parts a machine can check:
/// - every note in the playable range (C3…C5, the keyboard's 2 octaves) sounds
/// - 10 rapid repeated strikes produce no clicks/pops (no waveform
///   discontinuities, no clipping)
/// - note-off releases to silence (the seam's promised MIDI note-off path)
/// The remaining item — intelligible on the iPad bottom speaker at 30 %
/// volume — is subjective; it's on the device checklist in #34.
@MainActor
final class SampledPianoTests: XCTestCase {

    private static let sampleRate = 48_000.0
    /// In-bundle budget from #34.
    private static let bundleBudgetBytes = 20 * 1024 * 1024
    /// Keyboard range: `whiteKeyLane(startOctave: 3, octaveCount: 2)` renders
    /// C3…C5 — MIDI 48…72 (sharps included; MIDI input can strike them).
    private static let playableRange: ClosedRange<UInt8> = 48...72

    // MARK: Bundle + live boot

    func testSoundFontBundledAndUnderBudget() throws {
        let url = try XCTUnwrap(
            PianoSampler.soundFontURL,
            "\(PianoSampler.soundFontResource).sf2 missing from the app bundle")
        let size = try XCTUnwrap(
            try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        XCTAssertGreaterThan(size, 1024 * 1024, "suspiciously small soundfont — truncated resource?")
        XCTAssertLessThanOrEqual(size, Self.bundleBudgetBytes,
                                 "soundfont blew the ≤20 MB in-bundle budget (#34)")
    }

    /// The real live path: engine boots, SoundFont loads, sampler reports
    /// ready. This is the test that catches a broken resource reference —
    /// there is no synth fallback anymore.
    func testLiveSamplerBootsWithSampledPiano() {
        let sampler = PianoSampler()
        XCTAssertTrue(sampler.isReady, "sampler failed to boot: \(sampler.status)")
        XCTAssertTrue(sampler.status.contains("Upright Piano KW"),
                      "status should name the sampled instrument, got: \(sampler.status)")
        XCTAssertFalse(sampler.status.contains("synth"),
                       "synth placeholder is retired (#34), got: \(sampler.status)")
    }

    // MARK: Every playable note sounds

    func testEveryPlayableNoteSounds() {
        for midi in Self.playableRange {
            let buffer = PianoSampler.renderTone(pitch: Pitch(midi: midi), velocity: 100)
            let peak = Self.peak(of: buffer)
            XCTAssertGreaterThan(peak, 0.05, "MIDI \(midi) rendered (near-)silent — peak \(peak)")
        }
    }

    /// Velocity must still map to loudness (the synth had explicit amplitude
    /// buckets; now it's the AU's velocity curve on the sample layer).
    func testVelocityScalesLoudness() {
        let quiet = Self.peak(of: PianoSampler.renderTone(pitch: Pitch(midi: 60), velocity: 40))
        let loud = Self.peak(of: PianoSampler.renderTone(pitch: Pitch(midi: 60), velocity: 127))
        XCTAssertGreaterThan(loud, quiet * 1.5,
                             "velocity 127 (peak \(loud)) should be clearly louder than 40 (peak \(quiet))")
    }

    // MARK: renderTone contract (the B25 harness depends on this)

    func testRenderToneBufferContract() {
        let buffer = PianoSampler.renderTone(pitch: Pitch(midi: 60), velocity: 100)
        XCTAssertEqual(buffer.format.sampleRate, Self.sampleRate)
        XCTAssertEqual(buffer.format.channelCount, 1, "harness mixes mono")
        let seconds = Double(buffer.frameLength) / Self.sampleRate
        XCTAssertEqual(seconds, 2.5, accuracy: 0.1, "sustain + release window moved — update the harness expectations")
        // The tail must be genuinely released — a standing loop floor would
        // stack into a drone across a 13-song ear-check mix.
        let tailPeak = Self.peak(of: buffer, lastSeconds: 0.2)
        XCTAssertLessThan(tailPeak, 0.01, "tone doesn't decay to silence — tail peak \(tailPeak)")
    }

    // MARK: Khalid's gate — rapid repeated taps, no clicks

    /// Ten rapid strikes of the same key, 60 ms apart — a kid mashing. Rendered
    /// through a manual-rendering engine with the same SoundFont; asserts the
    /// waveform never jumps sample-to-sample like a voice being cut without a
    /// release ramp (a click), and never clips.
    func testTenRapidStrikesNoClicksNoClipping() throws {
        let engine = AVAudioEngine()
        let piano = AVAudioUnitSampler()
        engine.attach(piano)
        engine.connect(piano, to: engine.mainMixerNode, format: nil)
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        let url = try XCTUnwrap(PianoSampler.soundFontURL)
        try piano.loadSoundBankInstrument(
            at: url, program: 0,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0)
        try engine.start()
        defer { engine.stop() }

        let totalSeconds = 10 * 0.06 + 2.0
        let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(totalSeconds * Self.sampleRate) + 4096)!
        for _ in 0..<10 {
            piano.startNote(72, withVelocity: 110, onChannel: 0)
            try Self.render(engine, seconds: 0.06, into: buffer)
        }
        piano.stopNote(72, onChannel: 0)
        try Self.render(engine, seconds: 2.0, into: buffer)

        let data = buffer.floatChannelData![0]
        var maxJump: Float = 0
        var peak: Float = 0
        for i in 1..<Int(buffer.frameLength) {
            maxJump = max(maxJump, abs(data[i] - data[i - 1]))
            peak = max(peak, abs(data[i]))
        }
        XCTAssertGreaterThan(peak, 0.05, "rapid strikes rendered silent")
        XCTAssertLessThan(peak, 1.0, "rapid strikes clip")
        // Audition baseline was 0.026; a hard voice cut shows up as ≥ ~0.3.
        XCTAssertLessThan(maxJump, 0.15, "waveform discontinuity (click) — max jump \(maxJump)")
    }

    // MARK: Note-off path

    /// `stop(_:)` is now a real MIDI note-off (the promise at the old line
    /// 133). Offline: strike, ring 1 s, note-off, then the release tail must
    /// reach true silence — which the no-note-off loop floor never does.
    func testNoteOffReleasesToSilence() throws {
        let engine = AVAudioEngine()
        let piano = AVAudioUnitSampler()
        engine.attach(piano)
        engine.connect(piano, to: engine.mainMixerNode, format: nil)
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        let url = try XCTUnwrap(PianoSampler.soundFontURL)
        try piano.loadSoundBankInstrument(
            at: url, program: 0,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0)
        try engine.start()
        defer { engine.stop() }

        let buffer = AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: AVAudioFrameCount(3.5 * Self.sampleRate) + 4096)!
        piano.startNote(60, withVelocity: 100, onChannel: 0)
        try Self.render(engine, seconds: 1.0, into: buffer)
        let sustainPeak = Self.peak(of: buffer)
        piano.stopNote(60, onChannel: 0)
        try Self.render(engine, seconds: 2.5, into: buffer)
        let tailPeak = Self.peak(of: buffer, lastSeconds: 0.5)

        XCTAssertGreaterThan(sustainPeak, 0.05, "note never sounded")
        XCTAssertLessThan(tailPeak, 0.005,
                          "note-off release didn't reach silence — tail peak \(tailPeak)")
    }

    // MARK: Helpers

    private static func render(
        _ engine: AVAudioEngine, seconds: Double, into buffer: AVAudioPCMBuffer
    ) throws {
        let format = engine.manualRenderingFormat
        let chunk = AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: engine.manualRenderingMaximumFrameCount)!
        var remaining = AVAudioFrameCount(seconds * sampleRate)
        while remaining > 0 {
            let n = min(engine.manualRenderingMaximumFrameCount, remaining)
            let outcome = try engine.renderOffline(n, to: chunk)
            XCTAssertEqual(outcome, .success)
            let dst = buffer.floatChannelData![0] + Int(buffer.frameLength)
            dst.update(from: chunk.floatChannelData![0], count: Int(chunk.frameLength))
            buffer.frameLength += chunk.frameLength
            remaining -= chunk.frameLength
        }
    }

    private static func peak(of buffer: AVAudioPCMBuffer, lastSeconds: Double? = nil) -> Float {
        let data = buffer.floatChannelData![0]
        let frames = Int(buffer.frameLength)
        let start = lastSeconds.map { max(0, frames - Int($0 * sampleRate)) } ?? 0
        var peak: Float = 0
        for i in start..<frames {
            peak = max(peak, abs(data[i]))
        }
        return peak
    }
}
