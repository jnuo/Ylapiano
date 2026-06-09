import AVFoundation

/// Piano tone source for tap-to-play and (later) MIDI input. Renders
/// additive-synth piano tones with an exponential decay envelope, played
/// through a pool of `AVAudioPlayerNode`s for true polyphony — pressing
/// C and D in succession produces two overlapping decays, not a serial queue.
///
/// **Voice routing.** Each pitch is mapped to a specific voice via
/// `voiceByPitch` so a later `stop(_:)` (once we swap in the real sampler)
/// can target the actual voice that's playing that note. New strikes prefer
/// an idle voice (whose previous tone's decay has finished); if every voice
/// is still ringing the oldest is reused.
///
/// **Why synth, not Salamander yet:** the CC-BY 3.0 Salamander SF2 (~25 MB)
/// isn't bundled. Once it is, replace this body with AudioKit's `MIDISampler`
/// loaded via `loadMelodicSoundFont` — the `play(_:)` / `stop(_:)` signatures
/// stay identical so call sites don't change.
@MainActor
final class PianoSampler: ObservableObject {
    /// How long a struck tone keeps ringing before its voice counts as idle.
    /// Matches the buffer's audible envelope length (see `renderTone`).
    private static let voiceRingTime: TimeInterval = 1.5

    private let engine = AVAudioEngine()
    /// Each `AVAudioPlayerNode` plays its scheduled buffers serially, so true
    /// polyphony requires multiple nodes. 8 voices is more than enough for
    /// two-hand kids' piano.
    private let voices: [AVAudioPlayerNode]
    /// Wall-clock instant each voice was last struck. Used to find the
    /// oldest voice when no idle one is available, and to detect "still
    /// ringing."
    private var voiceLastStruck: [Date]
    /// Tracks which voice is currently playing a given pitch so `stop(_:)`
    /// can target it directly. Cleared as voices fall out of their ring
    /// window or get re-used.
    private var voiceByPitch: [UInt8: Int] = [:]
    /// Cache keyed by `(pitch, velocityBucket)`. Each velocity 0–127 maps
    /// to one of 8 buckets (`velocity / 16`), so striking the same key at
    /// noticeably different velocities now actually renders different
    /// amplitudes. With 8 buckets × ~25 in-range pitches × ~72 KB per buffer
    /// ≈ 14 MB worst case — trivial on iPad.
    ///
    /// **Rejected alternative**: cache at neutral velocity, scale per-strike
    /// via `AVAudioPlayerNode.volume`. `playerNode.volume` parameter-ramps
    /// over ~10 ms, audibly smearing velocity on fast repeated strikes.
    private var toneCache: [CacheKey: AVAudioPCMBuffer] = [:]

    /// Cache key — pitch + a coarse velocity bucket (8 buckets covering 1–127).
    private struct CacheKey: Hashable {
        let pitch: UInt8
        let velocityBucket: Int
    }

    // MARK: Hit-reward sparkle (juice slice)

    /// Separate celesta voices for the hit-reward "ting" so a reward never
    /// steals a ringing piano note. Two is plenty — sparkles are short.
    private let sparkleVoices: [AVAudioPlayerNode]
    private var nextSparkle = 0
    private var sparkleCache: [UInt8: AVAudioPCMBuffer] = [:]
    /// Major-pentatonic semitone steps — combo climbs these so a streak plays
    /// a rising melody that can't sound wrong over the song.
    private static let pentatonic = [0, 2, 4, 7, 9]

    @Published private(set) var status: String = "init"
    @Published private(set) var isReady = false

    init() {
        voices = (0..<8).map { _ in AVAudioPlayerNode() }
        sparkleVoices = (0..<2).map { _ in AVAudioPlayerNode() }
        voiceLastStruck = Array(repeating: .distantPast, count: 8)
        AudioSession.configurePlayback()
        setupEngine()
    }

    private func setupEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!
        for voice in voices + sparkleVoices {
            engine.attach(voice)
            engine.connect(voice, to: engine.mainMixerNode, format: format)
        }
        engine.prepare()
        do {
            try engine.start()
            for voice in voices + sparkleVoices { voice.play() }
            isReady = true
            status = "synth · \(voices.count)-voice (drop Salamander_C5_Light.sf2 to upgrade)"
            print("[PianoSampler] synth engine started @ 48 kHz, \(voices.count) voices")
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
            status = "engine start failed: \(error.localizedDescription)"
            print("[PianoSampler] \(status)")
        }
    }

    /// Strike `pitch`. Prefers a voice whose previous note has finished its
    /// decay tail; if every voice is still ringing it steals the oldest.
    func play(_ pitch: Pitch, velocity: UInt8 = 100) {
        guard isReady else { return }
        let key = CacheKey(pitch: pitch.midi, velocityBucket: Int(velocity) / 16)
        let buffer = toneCache[key] ?? Self.renderTone(pitch: pitch, velocity: velocity)
        toneCache[key] = buffer

        let voiceIndex = pickVoice()
        let voice = voices[voiceIndex]

        // If the voice was previously playing another pitch, drop that mapping
        // so a stale `stop(_:)` for the displaced pitch doesn't hit this voice.
        if let displaced = voiceByPitch.first(where: { $0.value == voiceIndex })?.key,
           displaced != pitch.midi {
            voiceByPitch.removeValue(forKey: displaced)
        }
        voiceByPitch[pitch.midi] = voiceIndex
        voiceLastStruck[voiceIndex] = Date()

        // `.interrupts` cuts any decaying tail still on this specific voice —
        // necessary so the new note starts cleanly at sample 0 instead of
        // queueing behind the old buffer.
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    /// In synth mode this is a no-op (buffers self-decay) but the voice
    /// mapping is cleared so subsequent strikes can reuse the slot freely.
    /// When Salamander loads, this becomes the MIDI note-off path.
    func stop(_ pitch: Pitch) {
        voiceByPitch.removeValue(forKey: pitch.midi)
    }

    /// Pre-render and cache tones for `pitches` so the FIRST strike of each note
    /// during play doesn't synthesize a ~72k-sample buffer inline on the main
    /// actor — an audible first-touch hitch on exactly the first impression.
    /// Call when a song loads; the cost is paid before the kid plays (e.g.
    /// during the count-in), never mid-performance.
    func prewarm(_ pitches: [Pitch], velocity: UInt8 = 100) {
        guard isReady else { return }
        let bucket = Int(velocity) / 16
        for pitch in pitches {
            let key = CacheKey(pitch: pitch.midi, velocityBucket: bucket)
            if toneCache[key] == nil {
                toneCache[key] = Self.renderTone(pitch: pitch, velocity: velocity)
            }
        }
    }

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

    /// Pick the next voice. Strategy: first idle voice (whose decay tail has
    /// finished), else the voice struck longest ago.
    private func pickVoice() -> Int {
        let now = Date()
        if let idle = voiceLastStruck.enumerated().first(where: { now.timeIntervalSince($0.element) >= Self.voiceRingTime })?.offset {
            return idle
        }
        // All ringing — steal the oldest.
        return voiceLastStruck.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
    }

    /// Additive synthesis: fundamental + 3 harmonics, exponential decay
    /// envelope (~1 s tail), 5 ms attack ramp to suppress clicks. Pure (no
    /// instance state) so `prewarm` and `play` can both render without touching
    /// `self` — keeps it cheap to call ahead of time.
    private static func renderTone(pitch: Pitch, velocity: UInt8) -> AVAudioPCMBuffer {
        let sampleRate = 48_000.0
        let frameCount = AVAudioFrameCount(Self.voiceRingTime * sampleRate)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        let data = buffer.floatChannelData![0]

        let frequency = pitch.frequency
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
