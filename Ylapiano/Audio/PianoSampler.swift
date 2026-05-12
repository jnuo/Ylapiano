import AVFoundation

/// Piano tone source for tap-to-play and (later) MIDI input. Renders
/// additive-synth piano tones with an exponential decay envelope, played
/// through a pool of `AVAudioPlayerNode`s for true polyphony — tapping
/// C and D in succession produces two overlapping decays, not a serial queue.
///
/// **Why synth, not Salamander yet:** the CC-BY 3.0 Salamander SF2 (~25 MB)
/// isn't bundled. Once it is, replace this body with AudioKit's `MIDISampler`
/// loaded via `loadMelodicSoundFont` — the `play(midiNote:)` / `stop(midiNote:)`
/// signatures stay identical so call sites don't change.
@MainActor
final class PianoSampler: ObservableObject {
    private let engine = AVAudioEngine()
    /// Each `AVAudioPlayerNode` plays its scheduled buffers serially, so true
    /// polyphony requires multiple nodes. 8 voices is more than enough for
    /// two-hand kids' piano (the last note's decay tail gets cut when the
    /// voice is reused on note 9).
    private let voices: [AVAudioPlayerNode]
    private var nextVoiceIndex = 0
    private var toneCache: [UInt8: AVAudioPCMBuffer] = [:]

    @Published private(set) var status: String = "init"
    @Published private(set) var isReady = false

    init() {
        voices = (0..<8).map { _ in AVAudioPlayerNode() }
        configureSession()
        setupEngine()
    }

    private func configureSession() {
        #if os(iOS) || os(visionOS) || os(tvOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(48_000)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            print("[PianoSampler] session config failed: \(error.localizedDescription)")
        }
        #endif
    }

    private func setupEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        for voice in voices {
            engine.attach(voice)
            engine.connect(voice, to: engine.mainMixerNode, format: format)
        }
        engine.prepare()
        do {
            try engine.start()
            for voice in voices { voice.play() }
            isReady = true
            status = "synth · \(voices.count)-voice (drop Salamander_C5_Light.sf2 to upgrade)"
            print("[PianoSampler] synth engine started @ 48 kHz, \(voices.count) voices")
        } catch {
            status = "engine start failed: \(error.localizedDescription)"
            print("[PianoSampler] \(status)")
        }
    }

    /// Strike a note. Buffer decays to silence on its own (~1 s), so no `stop`
    /// is needed for a tap. Round-robins through the voice pool so back-to-back
    /// taps don't serialize.
    func play(midiNote: UInt8, velocity: UInt8 = 100) {
        guard isReady else { return }
        let buffer = toneCache[midiNote] ?? renderTone(midiNote: midiNote, velocity: velocity)
        toneCache[midiNote] = buffer

        let voice = voices[nextVoiceIndex]
        nextVoiceIndex = (nextVoiceIndex + 1) % voices.count
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    /// No-op in synth mode — tones self-decay. Kept here so MIDI / on-screen
    /// keyboard call sites don't have to branch when we later swap in a real
    /// sampler that needs note-offs.
    func stop(midiNote: UInt8) { }

    /// Additive synthesis: fundamental + 3 harmonics, exponential decay
    /// envelope (~1 s tail), 5 ms attack ramp to suppress clicks.
    private func renderTone(midiNote: UInt8, velocity: UInt8) -> AVAudioPCMBuffer {
        let sampleRate = 48_000.0
        let duration: TimeInterval = 1.5
        let frequency = 440.0 * pow(2.0, (Double(midiNote) - 69.0) / 12.0)
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        let amp = 0.22 * min(max(Double(velocity) / 127.0, 0.4), 1.0)
        let twoPi = 2.0 * Double.pi
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 3.5)
            let attack = min(t * 200.0, 1.0)
            let fund = sin(twoPi * frequency * t)
            let h2 = 0.5  * sin(twoPi * frequency * 2.0 * t)
            let h3 = 0.25 * sin(twoPi * frequency * 3.0 * t)
            let h4 = 0.12 * sin(twoPi * frequency * 4.0 * t)
            data[i] = Float((fund + h2 + h3 + h4) * envelope * attack * amp)
        }
        return buffer
    }
}
