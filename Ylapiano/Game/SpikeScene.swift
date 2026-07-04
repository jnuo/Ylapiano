import SpriteKit
import SwiftUI

/// Sprint 0 Day 1 — Sync proof scene.
///
/// 60 notes scheduled at hitTime = 1, 2, 3, ..., 60 seconds. Every frame, each
/// visible note recomputes Y from `audioClock.currentTime`. If sync holds, every
/// note arrives at the hit line precisely on its scheduled second, with the
/// drift telemetry printed every 5s staying near zero.
final class SpikeScene: SKScene {
    weak var audioClock: AudioClock?

    private struct ScheduledNote {
        let hitTime: TimeInterval
        let lane: Int
        let node: SKShapeNode
    }

    private var scheduled: [ScheduledNote] = []
    private var hitLineY: CGFloat = 120
    private let leadTime: TimeInterval = 4.0
    private let pixelsPerSecond: CGFloat = 240
    private let lanes = 7
    private var lastTelemetrySecond = -1
    private var telemetryStartReal: CFTimeInterval?

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(Palette.cream)

        hitLineY = 140

        // Hit line strip — 4pt deep coral
        let line = SKShapeNode(rectOf: CGSize(width: size.width, height: 4))
        line.fillColor = UIColor(Palette.deepRed)
        line.strokeColor = .clear
        line.position = CGPoint(x: size.width / 2, y: hitLineY)
        line.zPosition = 10
        addChild(line)

        // Static lane separators (visual reference)
        let laneWidth = size.width / CGFloat(lanes)
        for i in 1..<lanes {
            let sep = SKShapeNode(rectOf: CGSize(width: 1, height: size.height))
            sep.fillColor = SKColor.black.withAlphaComponent(0.05)
            sep.strokeColor = .clear
            sep.position = CGPoint(x: laneWidth * CGFloat(i), y: size.height / 2)
            addChild(sep)
        }

        // HUD label — drift telemetry, top-left
        let label = SKLabelNode(fontNamed: "Menlo")
        label.name = "telemetry"
        label.fontSize = 16
        label.fontColor = UIColor(Palette.ink)
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .top
        label.position = CGPoint(x: 24, y: size.height - 24)
        label.zPosition = 100
        label.text = "warming up..."
        addChild(label)

        // Schedule 60 notes, one per second
        for i in 1...60 {
            let lane = (i - 1) % lanes
            scheduleNote(at: TimeInterval(i), lane: lane)
        }
    }

    private func scheduleNote(at hitTime: TimeInterval, lane: Int) {
        let laneWidth = size.width / CGFloat(lanes)
        let x = laneWidth * (CGFloat(lane) + 0.5)
        let node = SKShapeNode(rectOf: CGSize(width: laneWidth - 16, height: 64), cornerRadius: 10)
        node.fillColor = UIColor(Palette.deepRed)
        node.strokeColor = .clear
        node.position = CGPoint(x: x, y: size.height + 200) // off-screen
        node.alpha = 0
        node.zPosition = 5
        addChild(node)

        // Time label inside the note for visual debugging
        let timeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
        timeLabel.text = "\(Int(hitTime))s"
        timeLabel.fontSize = 22
        timeLabel.fontColor = .white
        timeLabel.verticalAlignmentMode = .center
        timeLabel.horizontalAlignmentMode = .center
        node.addChild(timeLabel)

        scheduled.append(ScheduledNote(hitTime: hitTime, lane: lane, node: node))
    }

    override func update(_ currentTime: TimeInterval) {
        guard let clock = audioClock else { return }
        let audioTime = clock.currentTime

        if telemetryStartReal == nil {
            telemetryStartReal = currentTime
        }

        for note in scheduled {
            let timeUntilHit = note.hitTime - audioTime
            if timeUntilHit > leadTime || timeUntilHit < -0.5 {
                if note.node.alpha != 0 { note.node.alpha = 0 }
                continue
            }
            note.node.alpha = 1
            let y = hitLineY + CGFloat(timeUntilHit) * pixelsPerSecond
            note.node.position = CGPoint(x: note.node.position.x, y: y)
        }

        // Drift telemetry every 5 seconds of audio time
        let intSec = Int(audioTime)
        if intSec > 0, intSec % 5 == 0, intSec != lastTelemetrySecond {
            lastTelemetrySecond = intSec
            let realElapsed = currentTime - (telemetryStartReal ?? currentTime)
            let drift = realElapsed - audioTime
            let line = String(
                format: "audioTime=%.3fs sceneTime=%.3fs drift=%+.3fms",
                audioTime, realElapsed, drift * 1000
            )
            print("[SpikeScene] \(line)")
            if let label = childNode(withName: "telemetry") as? SKLabelNode {
                label.text = line
            }
        }
    }
}
