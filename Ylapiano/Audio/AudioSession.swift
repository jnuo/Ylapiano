import AVFoundation

/// Single entry point for configuring the app's shared `AVAudioSession`.
///
/// Before this lived in one place, both `AudioClock` and `PianoSampler` each
/// called `setCategory` / `setActive` on the shared session in their own
/// `init`. Opening a song twice raced two ObservableObjects to mutate the
/// same singleton — sometimes the second `setActive(true)` failed silently
/// after the first had already activated. Funneling through here makes the
/// configuration idempotent and the call sites trivial.
enum AudioSession {
    /// Configure the shared session for low-latency music playback. Safe to
    /// call from multiple components — successive calls just re-apply the
    /// same settings (CoreAudio treats this as a no-op when nothing changed).
    static func configurePlayback() {
        #if os(iOS) || os(visionOS) || os(tvOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(48_000)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            print("[AudioSession] configurePlayback failed: \(error.localizedDescription)")
        }
        #endif
    }
}
