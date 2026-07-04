import SwiftUI

// MARK: - Hold-gate logic (B10 #22)

/// The rules behind the grown-up gate: a press must be HELD for
/// `requiredHold` seconds to unlock; releasing earlier cancels and resets.
/// A kid-style quick tap therefore does nothing at all.
///
/// Pure timing state, separated from `GrownUpGateButton` so the pass/cancel
/// rules are unit-testable with injected dates — no run loop, no gestures.
@MainActor
@Observable
final class HoldGateModel {
    /// How long a deliberate adult press must last. 2.5 s sits in the 2–3 s
    /// band: long enough that a random tap (or curious mashing) never opens
    /// the gate, short enough that a parent doesn't think it's broken.
    static let defaultHoldSeconds: TimeInterval = 2.5

    let requiredHold: TimeInterval
    /// 0…1 fill of the progress ring while a hold is in flight.
    private(set) var progress: Double = 0
    private(set) var isHolding = false
    private var holdStart: Date?

    init(requiredHold: TimeInterval = HoldGateModel.defaultHoldSeconds) {
        self.requiredHold = requiredHold
    }

    /// Finger down — a new hold attempt starts from zero.
    func begin(at now: Date = Date()) {
        holdStart = now
        isHolding = true
        progress = 0
    }

    /// Periodic tick while the finger stays down. Returns true exactly once,
    /// at the moment the hold crosses the threshold (the gate unlocks and the
    /// model resets, ready for the next hold).
    func update(now: Date = Date()) -> Bool {
        guard isHolding, let start = holdStart else { return false }
        progress = min(now.timeIntervalSince(start) / requiredHold, 1)
        if progress >= 1 {
            reset()
            return true
        }
        return false
    }

    /// Finger up before the threshold — the attempt is void, ring empties.
    func cancel() {
        reset()
    }

    private func reset() {
        isHolding = false
        holdStart = nil
        progress = 0
    }
}

// MARK: - Gate button

/// B10 (#22) — the reusable grown-up gate control: press-and-hold ~2.5 s with
/// a visible progress ring and a label only readers parse ("Hold for
/// grown-ups"). First consumer is the player's grown-ups drawer; Add Song and
/// the B17 Grown-Ups corner reuse this same component.
struct GrownUpGateButton: View {
    var label: String = "Hold for grown-ups"
    var onUnlock: () -> Void

    @State private var model = HoldGateModel()
    @State private var tickTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color(uiColor: .tertiarySystemFill), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(Palette.coral, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: ringProgress)
                Image(systemName: "lock.fill")
                    .font(.system(.footnote, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 6)
        .frame(height: 44)
        .contentShape(Rectangle())
        // DragGesture(minimumDistance: 0) = raw touch-down/up, which is what a
        // hold gate needs; Button/LongPressGesture would fire on release or
        // hide the in-flight progress.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !model.isHolding else { return }
                    model.begin()
                    startTicking()
                }
                .onEnded { _ in
                    model.cancel()
                    stopTicking()
                }
        )
        .onDisappear { stopTicking() }
        .accessibilityLabel(label)
        .accessibilityIdentifier("GrownUpGateButton")
    }

    /// Ring fill: the live hold, or the DEBUG screenshot override below.
    private var ringProgress: Double {
        #if DEBUG
        // UI-test / screenshot hook (same convention as -b26-demo-result-stars):
        // `-b10-gate-demo-progress 0.55` renders the ring frozen mid-hold so
        // the in-flight state can be captured deterministically. Never ships
        // set; a zero/absent default is a no-op.
        let demo = UserDefaults.standard.double(forKey: "b10-gate-demo-progress")
        if demo > 0 { return min(demo, 1) }
        #endif
        return model.progress
    }

    /// ~30 Hz progress ticks while the finger is down. The Task form (not a
    /// Timer) dies with the view and is trivially cancelled on release.
    private func startTicking() {
        stopTicking()
        tickTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                if model.update() {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onUnlock()
                    break
                }
                if !model.isHolding { break }
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }
}

#Preview {
    GrownUpGateButton { print("unlocked") }
        .padding()
}
