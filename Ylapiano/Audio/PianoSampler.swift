import AVFoundation

/// Piano tone source for tap-to-play and MIDI input. Plays a REAL sampled
/// piano — the FreePats "Upright Piano KW" SoundFont (CC0 1.0, see
/// ATTRIBUTIONS.md) — through an `AVAudioUnitSampler`, which handles
/// polyphony, velocity, voice stealing, and note-off release internally.
///
/// This retired the 4-harmonic additive-synth placeholder (B23, #34). The
/// `play(_:)` / `stop(_:)` seam is unchanged, so no call site moved:
/// `play` is MIDI note-on, `stop` is MIDI note-off.
///
/// **Auto note-off.** Taps never send note-off (`handleKeyReleased`
/// deliberately lets notes ring, mirroring a real piano without dampers).
/// The bundled SF2 loops its samples with a faint sustain floor (~-36 dBFS)
/// that would otherwise ring FOREVER, so each strike schedules its own
/// note-off after `autoNoteOffSeconds` — long past the audible decay, it
/// only silences the loop tail. A real `stop(_:)` (MIDI input) cancels the
/// pending one and releases immediately.
///
/// **Why Upright Piano KW, not Salamander:** the "Salamander C5 Light" SF2
/// the plan named is CC-BY-**NC** 4.0 — non-commercial, unusable here — and
/// the properly licensed Salamander SF2 is 296 MB (budget: ≤20 MB in-bundle).
/// FreePats' Upright Piano KW small SF2 is a real sampled piano, 9.5 MB,
/// CC0 1.0 (public domain — no attribution required, credited anyway).
@MainActor
final class PianoSampler: ObservableObject {
    /// Bundled SoundFont resource (in `Resources/Audio/`). FreePats
    /// "Upright Piano KW" by Gonzalo & Roberto (zenvoid.org), CC0 1.0.
    static let soundFontResource = "UprightPianoKW-small-20190703"

    /// How long a struck note rings before its scheduled note-off fires.
    /// The audible decay is over well before this; the note-off only stops
    /// the SF2's faint loop-sustain floor so mashed keys can't pile up into
    /// a standing drone (the AU has 64 voices — they must be freed).
    static let autoNoteOffSeconds: TimeInterval = 8

    private let engine = AVAudioEngine()
    /// The sampled piano. One sampler node is truly polyphonic — unlike the
    /// retired synth's hand-rolled `AVAudioPlayerNode` pool, note-on/off,
    /// velocity mapping, and voice stealing are the AU's job.
    private let piano = AVAudioUnitSampler()
    /// Pending auto note-off per pitch. A re-strike replaces the pending
    /// task so the ring window restarts; `stop(_:)` cancels it outright.
    private var autoNoteOff: [UInt8: Task<Void, Never>] = [:]

    // MARK: Hit-reward sparkle (juice slice)

    /// Separate celesta voices for the hit-reward "ting" so a reward never
    /// steals a ringing piano note. Two is plenty — sparkles are short.
    /// (The sparkle is a designed juice sound — hit-audio-spec.md — not part
    /// of the retired piano placeholder, so it stays synthesized.)
    private let sparkleVoices: [AVAudioPlayerNode]
    private var nextSparkle = 0
    private var sparkleCache: [UInt8: AVAudioPCMBuffer] = [:]
    /// Major-pentatonic semitone steps — combo climbs these so a streak plays
    /// a rising melody that can't sound wrong over the song.
    private static let pentatonic = [0, 2, 4, 7, 9]

    @Published private(set) var status: String = "init"
    @Published private(set) var isReady = false

    init() {
        sparkleVoices = (0..<2).map { _ in AVAudioPlayerNode() }
        AudioSession.configurePlayback()
        setupEngine()
    }

    private func setupEngine() {
        engine.attach(piano)
        // nil format: let the sampler output its native (stereo) format and
        // the mixer handle conversion.
        engine.connect(piano, to: engine.mainMixerNode, format: nil)
        let sparkleFormat = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        for voice in sparkleVoices {
            engine.attach(voice)
            engine.connect(voice, to: engine.mainMixerNode, format: sparkleFormat)
        }
        engine.prepare()
        do {
            guard let url = Self.soundFontURL else {
                throw NSError(domain: "PianoSampler", code: 1, userInfo: [
                    NSLocalizedDescriptionKey: "\(Self.soundFontResource).sf2 missing from bundle",
                ])
            }
            try piano.loadSoundBankInstrument(
                at: url, program: 0,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0
            )
            try engine.start()
            for voice in sparkleVoices { voice.play() }
            isReady = true
            status = "sampled · Upright Piano KW (CC0)"
            print("[PianoSampler] sampled piano started @ 48 kHz — \(Self.soundFontResource).sf2")
            #if os(iOS)
            // Real audio-path latency on THIS device + route. Marco's derisk
            // kill-gate: wired / built-in speaker should read < ~30 ms. Read it
            // from the Xcode console on a 60 Hz iPad, on speaker + wired + BT.
            let session = AVAudioSession.sharedInstance()
            print(String(
                format: "[PianoSampler] audio path — outputLatency=%.1f ms · ioBuffer=%.1f ms · sampleRate=%.0f Hz",
                session.outputLatency * 1000, session.ioBufferDuration * 1000, session.sampleRate
            ))
            #endif
        } catch {
            // No synth fallback — the placeholder is retired (#34). The SF2 is
            // a bundled resource; if it can't load, that's a build defect the
            // test suite catches (SampledPianoTests), not a runtime condition
            // to paper over with a silently different instrument.
            status = "soundfont load failed: \(error.localizedDescription)"
            isReady = false
            print("[PianoSampler] FAILED — \(status)")
            assertionFailure("[PianoSampler] \(status)")
        }
    }

    /// Bundle URL of the piano SoundFont. `Bundle(for:)` (not `.main`) so the
    /// hosted test bundle resolves to Ylapiano.app too.
    static var soundFontURL: URL? {
        Bundle(for: PianoSampler.self).url(
            forResource: soundFontResource, withExtension: "sf2")
    }

    /// Strike `pitch` — MIDI note-on. The AU allocates a voice, applies the
    /// velocity layer, and steals the oldest voice if all 64 are busy.
    func play(_ pitch: Pitch, velocity: UInt8 = 100) {
        guard isReady else { return }
        piano.startNote(pitch.midi, withVelocity: velocity, onChannel: 0)
        scheduleAutoNoteOff(pitch.midi)
    }

    /// Release `pitch` — the MIDI note-off path (the seam line 133 promised).
    /// Triggers the SF2 release envelope; the offline audition measured the
    /// tail at true silence within ~1 s, no click. Cancels the pending auto
    /// note-off so it can't double-fire.
    func stop(_ pitch: Pitch) {
        autoNoteOff.removeValue(forKey: pitch.midi)?.cancel()
        guard isReady else { return }
        piano.stopNote(pitch.midi, onChannel: 0)
    }

    /// Replace any pending note-off for `midi` and schedule a fresh one.
    private func scheduleAutoNoteOff(_ midi: UInt8) {
        autoNoteOff[midi]?.cancel()
        autoNoteOff[midi] = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.autoNoteOffSeconds))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.autoNoteOff.removeValue(forKey: midi)
            self.piano.stopNote(midi, onChannel: 0)
        }
    }

    /// Kept for the call-site seam (PlayerScreen prewarms on song load).
    /// With the synth this pre-rendered tone buffers; the sampler needs no
    /// warm-up — `loadSoundBankInstrument` made every sample resident at
    /// init — so this is intentionally a no-op.
    func prewarm(_ pitches: [Pitch], velocity: UInt8 = 100) {}

    // MARK: Sparkle (unchanged juice synth)

    /// Soft celesta "ting" layered over the piano note on a correct hit. Pitched
    /// to the octave above the played note (always consonant); `comboStep`
    /// climbs a pentatonic so a streak plays a rising melody that can't clash.
    /// Sits well under the piano note in the mix. Spec: hit-audio-spec.md.
    func playSparkle(base: Pitch, comboStep: Int, perfect: Bool) {
        guard isReady else { return }
        let step = max(comboStep, 0)
        let offset = Self.pentatonic[step % Self.pentatonic.count]
        let octaveBump = min(step / Self.pentatonic.count, 1) * 12   // climb ~1 octave, then hold
        let sparkleMidi = UInt8(clamping: min(Int(base.midi) + 12 + offset + octaveBump, 108))

        let buffer = sparkleCache[sparkleMidi] ?? Self.renderSparkle(midi: sparkleMidi)
        sparkleCache[sparkleMidi] = buffer

        let voice = sparkleVoices[nextSparkle]
        nextSparkle = (nextSparkle + 1) % sparkleVoices.count
        voice.volume = perfect ? 0.5 : 0.38            // under the piano note; PERFECT a touch brighter
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    /// Short bell/celesta one-shot: fundamental + bright, slightly inharmonic
    /// overtones, ~3 ms attack, fast exponential decay. Low amplitude so it
    /// seasons the piano note rather than competing with it.
    private static func renderSparkle(midi: UInt8) -> AVAudioPCMBuffer {
        let sampleRate = 48_000.0
        let frameCount = AVAudioFrameCount(0.45 * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        let freq = 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
        let amp = 0.10
        let twoPi = 2.0 * Double.pi
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let env = exp(-t * 6.0)
            let attack = min(t * 300.0, 1.0)
            let fundamental = sin(twoPi * freq * t)
            let h2 = 0.55 * sin(twoPi * freq * 2.0 * t)
            let h3 = 0.35 * sin(twoPi * freq * 3.0 * t)
            let h4 = 0.22 * sin(twoPi * freq * 4.2 * t)   // inharmonic → bell shimmer
            let harmonics = fundamental + h2 + h3 + h4
            data[i] = Float(harmonics * env * attack * amp)
        }
        return buffer
    }

    // MARK: Offline render (B25 ear-check seam)

    /// Sustain rendered before the offline note-off, and release rendered
    /// after it. 1.5 s sustain matches the retired synth's ring time (and the
    /// live feel of a tapped note); the audition measured the release tail at
    /// true silence well inside 1 s.
    private static let offlineSustainSeconds = 1.5
    private static let offlineReleaseSeconds = 1.0
    private static let offlineSampleRate = 48_000.0

    /// Offline engine + sampler reused across `renderTone` calls — loading
    /// the 9.5 MB SoundFont per note would make the 13-song ear-check crawl.
    private static var offlineEngine: AVAudioEngine?
    private static var offlinePiano: AVAudioUnitSampler?

    /// Render one struck note through the SAME sampled instrument the app
    /// plays live — note-on, `offlineSustainSeconds` of ring, note-off, then
    /// the release tail. Mono 48 kHz, like the synth buffers it replaced.
    ///
    /// Internal (not private) so the B25 ear-check harness
    /// (`EarCheckRenderTests`) can render songs offline through the exact
    /// same tone path the app plays live — that's the whole point of the
    /// shared seam. Not used by the live path anymore (the AU renders in
    /// real time); test/tooling only, hence `preconditionFailure` on setup
    /// errors instead of a fallback.
    static func renderTone(pitch: Pitch, velocity: UInt8) -> AVAudioPCMBuffer {
        do {
            let (engine, piano) = try offlineRenderer()
            let format = engine.manualRenderingFormat
            let totalFrames = AVAudioFrameCount(
                (offlineSustainSeconds + offlineReleaseSeconds) * offlineSampleRate)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames)!

            piano.startNote(pitch.midi, withVelocity: velocity, onChannel: 0)
            try render(engine, seconds: offlineSustainSeconds, into: buffer)
            piano.stopNote(pitch.midi, onChannel: 0)
            try render(engine, seconds: offlineReleaseSeconds, into: buffer)
            // Clear residual voice/reverb state so the next call starts clean.
            engine.reset()
            return buffer
        } catch {
            preconditionFailure("[PianoSampler] offline renderTone failed: \(error)")
        }
    }

    /// Lazily build the reusable manual-rendering engine with the bundled
    /// SoundFont loaded.
    private static func offlineRenderer() throws -> (AVAudioEngine, AVAudioUnitSampler) {
        if let engine = offlineEngine, let piano = offlinePiano {
            return (engine, piano)
        }
        guard let url = soundFontURL else {
            throw NSError(domain: "PianoSampler", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "\(soundFontResource).sf2 missing from bundle",
            ])
        }
        let engine = AVAudioEngine()
        let piano = AVAudioUnitSampler()
        engine.attach(piano)
        engine.connect(piano, to: engine.mainMixerNode, format: nil)
        let format = AVAudioFormat(standardFormatWithSampleRate: offlineSampleRate, channels: 1)!
        try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        try piano.loadSoundBankInstrument(
            at: url, program: 0,
            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0)
        try engine.start()
        offlineEngine = engine
        offlinePiano = piano
        return (engine, piano)
    }

    /// Pull `seconds` of audio out of the manual-rendering engine, appending
    /// to `buffer` (which must have capacity for it).
    private static func render(
        _ engine: AVAudioEngine, seconds: Double, into buffer: AVAudioPCMBuffer
    ) throws {
        let format = engine.manualRenderingFormat
        let chunk = AVAudioPCMBuffer(
            pcmFormat: format, frameCapacity: engine.manualRenderingMaximumFrameCount)!
        var remaining = AVAudioFrameCount(seconds * offlineSampleRate)
        while remaining > 0 {
            let n = min(engine.manualRenderingMaximumFrameCount, remaining)
            let outcome = try engine.renderOffline(n, to: chunk)
            guard outcome == .success else {
                throw NSError(domain: "PianoSampler", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "manual render returned \(outcome)",
                ])
            }
            let dst = buffer.floatChannelData![0] + Int(buffer.frameLength)
            dst.update(from: chunk.floatChannelData![0], count: Int(chunk.frameLength))
            buffer.frameLength += chunk.frameLength
            remaining -= chunk.frameLength
        }
    }
}
