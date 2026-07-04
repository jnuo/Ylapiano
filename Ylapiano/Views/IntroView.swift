import AVFoundation
import SwiftUI

/// #56 (B31) — the cold-launch intro: Pim's animated opening moment.
///
/// A 4 s seamless loop (HyperFrames keyframed composition built from the B7
/// canon stills — no net-new art, canon preserved exactly) plays centered on
/// `Palette.pimCream`: Pim bounces on a 0.5 s beat over an octave of piano
/// keys lighting up Do→Do, notes float up, and bars 5–6 swap to the cheer
/// pose with bigger hops. The clip bakes its own pimCream ground (no alpha),
/// so the player is a plain muted `AVPlayerLayer` loop — `SongResultView`'s
/// chroma-key `LoopingVideoView` exists for green-screen clips and would
/// spend a per-frame Core Image pass here for nothing.
///
/// Product rules (#56): cold launch only (once per process, `IntroGate`),
/// tap ANYWHERE skips instantly, auto-advance after one loop pass, Reduce
/// Motion gets the static canon still on the same timing, and nothing here
/// blocks data load — home is mounted (and seeding) underneath the overlay.
struct IntroView: View {
    /// Test seam: forces the Reduce Motion branch deterministically.
    /// `nil` (production) defers to the system setting.
    var reduceMotionOverride: Bool? = nil
    /// The shared engine, handed in by `ContentView`. Soft Do–Mi–Sol dings
    /// (B11's star-ding render seam) ride the first bounces; `nil` (tests)
    /// or a not-yet-ready engine simply stays silent — that's acceptable.
    var sampler: PianoSampler? = nil
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var finished = false

    private var reduceMotion: Bool { reduceMotionOverride ?? systemReduceMotion }

    var body: some View {
        ZStack {
            Palette.pimCream.ignoresSafeArea()

            if let url = IntroDesign.videoURL, !reduceMotion {
                IntroLoopVideoView(url: url)
                    .accessibilityHidden(true)
            } else {
                // Reduce Motion (or a missing clip): the static canon still —
                // same timing, same tap-to-skip.
                Image("MascotGreeting")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 520)
                    .padding(40)
                    .accessibilityHidden(true)
            }

            // App name stays small — Pim is the hero (#56).
            VStack {
                Spacer()
                Text("Ylapiano")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Palette.ink.opacity(0.7))
                    .padding(.bottom, 24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() } // tap anywhere skips instantly
        .accessibilityIdentifier("IntroScreen")
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Skip intro")
        .task {
            // Soft piano notes through the shared engine, synced to the
            // bounce beat. Not gated on Reduce Motion — sound is not motion
            // (the B11 precedent), and there is no sound gate (#56).
            for index in 0..<IntroDesign.dingCount {
                guard !finished else { break }
                sampler?.playStarDing(index)
                try? await Task.sleep(for: .seconds(IntroDesign.dingBeatSeconds))
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(IntroDesign.autoAdvanceSeconds))
            finish()
        }
    }

    /// Idempotent — a tap racing the auto-advance must finish exactly once.
    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

/// The intro's product contract, as named constants so `IntroTests` can hold
/// the bar (≤ one loop pass on screen, instant skip, seam-aligned exit).
enum IntroDesign {
    /// The bundled loop clip. `nil` (missing resource) falls back to the
    /// static still branch — the intro never blocks on a broken bundle.
    static var videoURL: URL? {
        Bundle.main.url(forResource: "PimIntro", withExtension: "mp4")
    }

    /// The clip's length — one full pass of the seamless loop.
    static let loopSeconds: Double = 4.0
    /// Auto-advance to home after exactly one pass, landing on the loop's
    /// seam frame (first frame == last frame) so the exit never stutters.
    static let autoAdvanceSeconds: Double = 4.0
    /// Cross-fade into home when the intro ends.
    static let fadeOutSeconds: Double = 0.25
    /// Do–Mi–Sol on the first bounces — the clip's beat is 0.5 s (120 BPM).
    static let dingBeatSeconds: Double = 0.5
    static let dingCount = 3
}

/// Once-per-process gate: cold launch shows the intro, foregrounding never
/// re-triggers it (the flag lives for the process lifetime, not the scene
/// phase).
enum IntroGate {
    private(set) static var hasShownThisLaunch = false

    /// True exactly once per process launch. UI-test launches — which always
    /// inject `-hasCompletedOnboarding` (an override no real launch carries)
    /// — skip the intro entirely so 4 s of overlay can't eat their first tap.
    /// Screenshot-seed launches (B20 `-screenshotState`) skip it for the same
    /// reason: the seeded state must never race a 4 s overlay.
    static func consumeShouldShow(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> Bool {
        guard !hasShownThisLaunch else { return false }
        hasShownThisLaunch = true
        return !arguments.contains("-hasCompletedOnboarding")
            && ScreenshotSeed.profile(from: arguments) == nil
    }

    /// Test seam.
    static func reset() { hasShownThisLaunch = false }
}

// MARK: - Plain looping player (no chroma key)

private struct IntroLoopVideoView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> IntroPlayerUIView { IntroPlayerUIView(url: url) }
    func updateUIView(_ uiView: IntroPlayerUIView, context: Context) {}
}

/// Muted `AVPlayerLayer` on a seamless loop, aspect-fit (Pim is never
/// stretched), transparent letterbox so the screen's pimCream shows through.
private final class IntroPlayerUIView: UIView {
    private let player = AVPlayer()
    private var endObserver: NSObjectProtocol?

    override static var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer {
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer
    }

    init(url: URL) {
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        playerLayer.videoGravity = .resizeAspect
        playerLayer.player = player

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.isMuted = true // intro notes come from the shared engine, not the clip
        player.actionAtItemEnd = .none

        // Seamless loop: zero-tolerance seek back to the seam frame.
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            self?.player.play()
        }
        player.play()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
}

#Preview {
    IntroView(onFinish: {})
}
