import AVFoundation

/// Single entry point for configuring the app's shared `AVAudioSession` —
/// the ONLY file allowed to mutate it (pinned by `SingleAudioSessionTests`).
///
/// Before this lived in one place, both `AudioClock` and `PianoSampler` each
/// called `setCategory` / `setActive` on the shared session in their own
/// `init` (and `Metronome` kept a mic-era record-capable category of its
/// own, B5 #27). Opening a song twice raced two ObservableObjects to mutate the
/// same singleton — sometimes the second `setActive(true)` failed silently
/// after the first had already activated. Funneling through here makes the
/// configuration idempotent and the call sites trivial.
///
/// **Silent switch / mute:** `.playback` plays through the ring/silent
/// switch — deliberate, and correct for a music app the player just asked to
/// make sound (same choice every rhythm game and music app makes). Because
/// the count-in/metronome tocks also route through the engine (B6 #14), the
/// piano and the tocks behave IDENTICALLY: all on media volume, all
/// unaffected by the mute switch. On a device muted via media volume the
/// fallback is visual — the key-glow guidance (see the B11 audio acceptance
/// notes).
enum AudioSession {
    /// Category/preferences applied once per process (see `configurePlayback`).
    private static var isConfigured = false

    /// Configure the shared session for low-latency music playback. Safe to
    /// call from multiple components: the category + preferred settings are
    /// applied exactly once per launch, and later calls only re-assert
    /// `setActive(true)` (cheap, and recovers activation if the system
    /// deactivated the session behind our back).
    static func configurePlayback() {
        #if os(iOS) || os(visionOS) || os(tvOS)
        let session = AVAudioSession.sharedInstance()
        do {
            if !isConfigured {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try session.setPreferredSampleRate(48_000)
                try session.setPreferredIOBufferDuration(0.005)
                isConfigured = true
            }
            try session.setActive(true)
        } catch {
            print("[AudioSession] configurePlayback failed: \(error.localizedDescription)")
        }
        #endif
    }
}
