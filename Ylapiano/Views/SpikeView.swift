import SwiftUI
import SpriteKit

/// Sprint 0 Day 1 — Sync proof harness.
///
/// Runs the `SpikeScene` against an `AudioClock`. Watch the on-screen drift
/// readout (and Xcode console) — it should stay within a few ms of zero across
/// the full 60s run. If drift accumulates, the master-clock architecture is
/// wrong and we redesign before any further sprint work.
struct SpikeView: View {
    @StateObject private var audioClock = AudioClock()
    @State private var scene: SpikeScene = {
        let s = SpikeScene(size: CGSize(width: 1366, height: 1024))
        s.scaleMode = .resizeFill
        return s
    }()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.gray.opacity(0.7), .white.opacity(0.9))
            }
            .padding(20)
        }
        .onAppear {
            scene.audioClock = audioClock
            audioClock.resetClock()
        }
    }
}

#Preview {
    SpikeView()
}
