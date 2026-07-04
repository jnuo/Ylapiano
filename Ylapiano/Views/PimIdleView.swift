import SwiftUI

/// #38 (B27) — Pim's idle presence on the home screen.
///
/// A dead first screen reads as abandoned, so Pim breathes, blinks, and
/// occasionally tilts his head in the home header. No idle mp4 exists (the
/// three `PimResult*.mp4` clips are result REACTIONS — "hmm, again!", clap,
/// jump-cheer — none reads as calm idle), so the idle is pure code-driven
/// motion on the canon `MascotGreeting` still: no new art, no video decode.
///
/// Restraint is the design (Pok Pok bar): breathe is a 2 s ease at 2%, a
/// blink lands every ~3 s, a ±2° head-tilt every second blink. The idle must
/// never compete with the song cards — B9's star-pop owns card motion.
///
/// Power/CPU: no `Timer`, no `CADisplayLink`, no per-frame `TimelineView`.
/// Breathe and tilt are single Core-Animation-backed eases; the blink is a
/// discrete state flip from one slow `Task` loop that sleeps between beats.
///
/// Reduce Motion renders the plain still — no overlay, no loop.
struct PimIdleView: View {
    /// Test seam: forces the Reduce Motion branch deterministically.
    /// `nil` (production) defers to the system setting.
    var reduceMotionOverride: Bool? = nil

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var breathing = false
    @State private var eyesClosed = false
    @State private var tilt: Double = 0
    @State private var idleTask: Task<Void, Never>? = nil

    private var reduceMotion: Bool { reduceMotionOverride ?? systemReduceMotion }

    var body: some View {
        Image("MascotGreeting")
            .resizable()
            .scaledToFit()
            .overlay { if !reduceMotion { eyelids } }
            .rotationEffect(.degrees(tilt), anchor: .bottom)
            .scaleEffect(x: 1, y: breathing ? PimIdleMotion.breatheScale : 1, anchor: .bottom)
            .accessibilityHidden(true) // decorative — Pim says nothing here
            .onAppear(perform: startIdle)
            .onDisappear(perform: stopIdle)
            .onChange(of: scenePhase) { _, phase in
                // The clip-player AC translated to code-motion: pause when the
                // app backgrounds, resume on foreground.
                if phase == .active { startIdle() } else { stopIdle() }
            }
    }

    // MARK: - Blink overlay

    /// Two stylized eyelids over the still's measured eye positions: a
    /// `pimCream` ellipse hides the open eye (the face patch around both eyes
    /// is that exact sampled cream) and an `ink` ∩-arc mimics the closed-eye
    /// linework of the canon `MascotCheer` pose. Both tokens were sampled
    /// from the Pim stills, so the lids sit seamlessly on the art.
    private var eyelids: some View {
        GeometryReader { geo in
            // MascotGreeting is square, so the fitted rect IS the view bounds.
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                eyelid(PimIdleMotion.leftEye, side: side)
                eyelid(PimIdleMotion.rightEye, side: side)
            }
        }
        .opacity(eyesClosed ? 1 : 0)
    }

    private func eyelid(_ eye: PimIdleMotion.Eye, side: CGFloat) -> some View {
        let w = eye.width * side
        let h = eye.height * side
        return ZStack {
            Ellipse()
                .fill(Palette.pimCream)
                .frame(width: w, height: h)
            ClosedEyeArc()
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: h * 0.16, lineCap: .round))
                .frame(width: w * 0.68, height: h * 0.26)
        }
        .position(x: eye.x * side, y: eye.y * side)
    }

    // MARK: - Idle loop

    private func startIdle() {
        guard !reduceMotion, idleTask == nil else { return }
        withAnimation(
            .easeInOut(duration: PimIdleMotion.breathePeriod).repeatForever(autoreverses: true)
        ) {
            breathing = true
        }
        idleTask = Task { @MainActor in
            var blinkCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(.random(in: PimIdleMotion.blinkInterval)))
                guard !Task.isCancelled else { break }
                // A blink is abrupt on purpose — a fade reads as drowsy.
                eyesClosed = true
                try? await Task.sleep(for: .milliseconds(PimIdleMotion.blinkClosedMilliseconds))
                eyesClosed = false
                blinkCount += 1

                // Every second blink (~6–8 s), a gentle head-tilt, alternating
                // sides so Pim doesn't develop a lean.
                if blinkCount.isMultiple(of: PimIdleMotion.tiltEveryNthBlink) {
                    guard !Task.isCancelled else { break }
                    try? await Task.sleep(for: .milliseconds(600))
                    let side: Double = blinkCount.isMultiple(of: PimIdleMotion.tiltEveryNthBlink * 2) ? -1 : 1
                    withAnimation(.easeInOut(duration: 0.55)) { tilt = side * PimIdleMotion.tiltDegrees }
                    try? await Task.sleep(for: .milliseconds(1400))
                    withAnimation(.easeInOut(duration: 0.55)) { tilt = 0 }
                }
            }
        }
    }

    private func stopIdle() {
        idleTask?.cancel()
        idleTask = nil
        eyesClosed = false
        withAnimation(.easeOut(duration: 0.2)) {
            breathing = false
            tilt = 0
        }
    }
}

/// The idle's motion contract, kept as named constants so `PimIdleTests` can
/// hold the restraint bar (Diego's spec: 2–4 s loop, ≤2% breathe, ≤2° tilt)
/// against drive-by tweaks.
enum PimIdleMotion {
    /// Breathe amplitude — bottom-anchored y-scale peak.
    static let breatheScale: CGFloat = 1.02
    /// Seconds per breathe half-cycle (inhale OR exhale).
    static let breathePeriod: Double = 2.0
    /// Seconds between blinks (randomized so the loop never reads as a GIF).
    static let blinkInterval: ClosedRange<Double> = 2.8...4.0
    /// How long the eyes stay shut.
    static let blinkClosedMilliseconds = 120
    /// Head-tilt amplitude in degrees.
    static let tiltDegrees: Double = 2
    /// A tilt rides along every Nth blink (2 ⇒ every ~6–8 s).
    static let tiltEveryNthBlink = 2

    /// One eye's footprint, normalized to the square MascotGreeting still.
    /// Measured off the PNG's dark-iris pixel blobs, padded ~20% so the lid
    /// also covers the eye's own outline ring.
    struct Eye {
        let x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat
    }

    static let leftEye = Eye(x: 0.380, y: 0.339, width: 0.076, height: 0.078)
    static let rightEye = Eye(x: 0.536, y: 0.368, width: 0.070, height: 0.070)
}

/// The ∩-shaped closed-eye stroke — same silhouette as MascotCheer's happy
/// shut eyes, so a blinking Pim stays on-model.
private struct ClosedEyeArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height)
        )
        return path
    }
}

#Preview {
    PimIdleView()
        .frame(width: 160, height: 160)
        .padding()
        .background(Palette.cream)
}
