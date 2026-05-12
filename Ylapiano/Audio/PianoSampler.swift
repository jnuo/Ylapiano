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
    private var toneCache: [UInt8: AVAudioPCMBuffer] = [:]

    @Published private(set) var status: String = "init"
    @Published private(set) var isReady = false

    init() {
        voices = (0..<8).map { _ in AVAudioPlayerNode() }
        voiceLastStruck = Array(repeating: .distantPast, count: 8)
        AudioSession.configurePlayback()
        setupEngine()
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

    /// Strike `pitch`. Prefers a voice whose previous note has finished its
    /// decay tail; if every voice is still ringing it steals the oldest.
    func play(_ pitch: Pitch, velocity: UInt8 = 100) {
        guard isReady else { return }
        let buffer = toneCache[pitch.midi] ?? renderTone(pitch: pitch, velocity: velocity)
        toneCache[pitch.midi] = buffer

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
    /// envelope (~1 s tail), 5 ms attack ramp to suppress clicks.
    private func renderTone(pitch: Pitch, velocity: UInt8) -> AVAudioPCMBuffer {
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
