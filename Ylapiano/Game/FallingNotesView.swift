import SwiftUI
import SpriteKit

/// SwiftUI wrapper around `FallingNotesScene`. Sits in the same slot as
/// `ABCMusicView` in `PlayerScreen`; lane columns align 1:1 with the white
/// keys of `PianoKeyboardView` below so a falling note's bottom edge lands
/// directly over the key the kid needs to press.
///
/// **Timing inputs** come from `PlayerViewModel` so the scene is always in
/// sync with the rest of the playback pipeline — even if the user switches
/// to falling-notes mode 30 s into a song that started in sheet-music mode.
struct FallingNotesView: UIViewRepresentable {
    let song: Song
    let playStartedAt: Date?
    let accumulatedBeforePause: TimeInterval
    let bpm: Int
    /// Latest judged press; forwarded to the scene once per new `id`.
    let lastHit: HitEvent?
    /// When true the scene plays the metronome beat (synced to the blocks).
    let beatsEnabled: Bool

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60

        let scene = FallingNotesScene(song: song, size: CGSize(width: 1024, height: 480))
        view.presentScene(scene)
        context.coordinator.scene = scene
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        guard let scene = context.coordinator.scene else { return }
        scene.playStartedAt = playStartedAt
        scene.accumulatedBeforePause = accumulatedBeforePause
        scene.currentBPM = bpm
        scene.beatsEnabled = beatsEnabled

        // Forward each new judged press into the scene exactly once.
        if let hit = lastHit, hit.id != context.coordinator.lastHitID {
            context.coordinator.lastHitID = hit.id
            scene.registerHit(lane: hit.lane, judgment: hit.judgment, combo: hit.combo)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator {
        var scene: FallingNotesScene?
        var lastHitID = 0
    }
}
