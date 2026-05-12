import AVFoundation
import Foundation

/// Master timing source for the falling-notes game. Reads `lastRenderTime`
/// from a running `AVAudioEngine` so visuals stay locked to the audio
/// render thread, not wall-clock time.
///
/// Sprint 0 Day 1 — pure clock, no sampler attached yet.
@MainActor
final class AudioClock: ObservableObject {
    let engine = AVAudioEngine()

    /// Silent player node, attached only so the engine has a non-empty graph
    /// and `prepare()` succeeds. Sprint 0 Day 1 — no audio is actually played.
    /// Sprint 1 will replace this with the real sampler.
    private let silentPlayer = AVAudioPlayerNode()

    /// Audio render time captured the moment the engine started.
    /// `currentTime` is computed as the delta from this anchor.
    private var anchor: AVAudioTime?

    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    init() {
        AudioSession.configurePlayback()
        startEngine()
    }

    private func startEngine() {
        // Attach + connect a silent player so the engine graph is non-empty.
        // Without this, `prepare()` throws "inputNode != nullptr || outputNode != nullptr".
        engine.attach(silentPlayer)
        engine.connect(silentPlayer, to: engine.mainMixerNode, format: nil)

        engine.prepare()
        do {
            try engine.start()
            anchor = engine.outputNode.lastRenderTime
            isRunning = true
            print("[AudioClock] engine started, sampleRate=\(engine.outputNode.outputFormat(forBus: 0).sampleRate)")
        } catch {
            lastError = "Engine start failed: \(error.localizedDescription)"
            isRunning = false
            print("[AudioClock] \(lastError ?? "")")
        }
    }

    /// Seconds since the engine started, derived from the audio render clock.
    /// Returns 0 until both anchor and a valid current render time exist.
    var currentTime: TimeInterval {
        guard let now = engine.outputNode.lastRenderTime,
              let start = anchor,
              now.isSampleTimeValid, start.isSampleTimeValid
        else { return 0 }
        let elapsedFrames = now.sampleTime - start.sampleTime
        let sampleRate = now.sampleRate > 0 ? now.sampleRate : 48_000
        return Double(elapsedFrames) / sampleRate
    }

    /// Reset the time anchor to "now."
    func resetClock() {
        anchor = engine.outputNode.lastRenderTime
    }
}
