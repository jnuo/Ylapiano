import SpriteKit
import UIKit

/// Falling-notes lane for a single song. Each note becomes a rounded coral
/// rectangle in the lane that matches its pitch's white-key column on the
/// keyboard below; the rectangle's height represents its duration. As the
/// scene's `update(_:)` ticks, every rectangle's Y is recomputed so its
/// bottom edge crosses the hit line at exactly the moment the player should
/// strike that note.
///
/// **Timing source.** This scene does NOT own its own clock. SwiftUI's
/// `FallingNotesView` feeds in `playStartedAt` + `accumulatedBeforePause`
/// from `PlayerViewModel`, which is the single source of truth shared with
/// the rest of the playback pipeline (abcjs cursor, metronome). Mode switches
/// or pause/resume cycles can never drift because every reader derives
/// `elapsedSeconds` from the same two values.
///
/// **BPM-aware.** Note positions are stored in **beats** (not seconds). The
/// metronome's current BPM is read every frame to convert beats → seconds,
/// so changing tempo mid-song stays in sync.
final class FallingNotesScene: SKScene {
    private let song: Song
    /// Geometry comes from `KeyboardLayout.default` so this scene's lanes
    /// can never drift from the keys `PianoKeyboardView` is rendering below.
    private let layout = KeyboardLayout.default
    private var laneCount: Int { layout.whiteKeyCount }
    private var startOctave: Int { layout.startOctave }
    private var octaveCount: Int { layout.octaveCount }
    private let pixelsPerSecond: CGFloat = 240
    private let leadTime: TimeInterval = 4.0

    private struct ScheduledNote {
        let hitBeat: Double          // when (in beats from t=0) the note bottom should cross the hit line
        let lengthBeats: Double      // duration in beats
        let lane: Int
        let node: SKShapeNode
    }

    private var scheduled: [ScheduledNote] = []

    /// Nodes already celebrated this play-through — skipped by `update` so the
    /// pop animation isn't fought by per-frame repositioning. Cleared on a
    /// fresh play (detected via `lastElapsed` jumping backward) and on rebuild.
    private var poppedNodes: Set<ObjectIdentifier> = []
    private var lastElapsed: TimeInterval = 0

    /// When true, the scene plays a metronome tock as each beat crosses — off
    /// the SAME `elapsedBeats` that positions the blocks, so the beat you HEAR
    /// and the block you SEE can't drift (they're one clock, one frame). This
    /// replaces the old free-running `Timer` metronome that ran on its own
    /// timebase. Scales with tempo automatically (elapsedBeats uses live bpm).
    var beatsEnabled = false
    private var lastBeatTocked = -1

    /// Makes the tock SOUND when this scene decides a beat crossed. Set by
    /// `FallingNotesView` to `PianoSampler.playTock()` so the beat plays
    /// through the shared `AVAudioEngine` — media volume, same silent-switch
    /// behavior as the piano — instead of the old ringer-volume system sound
    /// (B6 #14). The scene keeps the WHEN (its clock); the sampler owns the
    /// HOW (the sound).
    var onBeat: (() -> Void)?

    /// Fired once when the last bar has fallen past the line (+ a short tail),
    /// off this scene's own clock. Drives the end-of-song result.
    var onSongEnd: (() -> Void)?
    private var endFired = false
    private var maxHitBeat: Double = 0

    /// Set by SwiftUI from `PlayerViewModel`. While `playStartedAt` is non-nil
    /// the song is playing (elapsed advances live via `Date()`). While `nil`
    /// + `accumulatedBeforePause > 0` it is paused (elapsed is frozen).
    /// While both are zero/nil the song is stopped → all notes hidden.
    var playStartedAt: Date?
    var accumulatedBeforePause: TimeInterval = 0
    /// Rebuilds the scheduled-note shapes whenever the song's tempo changes
    /// — the pre-baked rectangle heights must be re-rendered, otherwise a
    /// half note at 60 BPM keeps its 480 pt body when the player slides
    /// tempo up to 120 and the on-screen note would overhang its hit.
    var currentBPM: Int = 60 {
        didSet {
            guard oldValue != currentBPM, size.width > 0, size.height > 0 else { return }
            rebuildLayout()
        }
    }

    private var elapsedSeconds: TimeInterval {
        if let started = playStartedAt {
            return accumulatedBeforePause + Date().timeIntervalSince(started)
        }
        return accumulatedBeforePause
    }

    init(song: Song, size: CGSize) {
        self.song = song
        super.init(size: size)
        backgroundColor = SKColor(red: 1.0, green: 0.97, blue: 0.93, alpha: 1.0) // cream
        scaleMode = .resizeFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMove(to view: SKView) {
        // Layout deferred to `didChangeSize` — at presentScene time the
        // SwiftUI-driven SKView is still 0×0.
        if size.width > 0, size.height > 0 {
            rebuildLayout()
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0 else { return }
        rebuildLayout()
    }

    private func rebuildLayout() {
        removeAllChildren()
        scheduled.removeAll()
        poppedNodes.removeAll()
        drawLaneGrid()
        drawHitLine()
        buildScheduledNotes()
    }

    // MARK: - Static decoration

    private func drawLaneGrid() {
        let laneWidth = size.width / CGFloat(laneCount)
        for i in 1..<laneCount {
            let sep = SKShapeNode(rectOf: CGSize(width: 0.5, height: size.height))
            sep.fillColor = SKColor.black.withAlphaComponent(0.04)
            sep.strokeColor = .clear
            sep.position = CGPoint(x: laneWidth * CGFloat(i), y: size.height / 2)
            addChild(sep)
        }
    }

    private func drawHitLine() {
        let height: CGFloat = 6
        let line = SKShapeNode(rectOf: CGSize(width: size.width, height: height))
        line.fillColor = SKColor(red: 0.84, green: 0.16, blue: 0.16, alpha: 1.0) // deep coral
        line.strokeColor = .clear
        line.position = CGPoint(x: size.width / 2, y: height / 2)
        line.zPosition = 10
        addChild(line)
    }

    // MARK: - Note scheduling

    private func buildScheduledNotes() {
        let laneWidth = size.width / CGFloat(laneCount)
        var cumulativeBeats: Double = 0

        for entry in song.notes {
            let hitBeat = cumulativeBeats
            let lengthBeats = entry.duration.beats
            cumulativeBeats += lengthBeats

            if entry.isRest { continue }   // a rest is a gap, not a block

            let pitch = Pitch(solfege: entry.solfege, octave: entry.octave)
            guard let lane = layout.laneIndex(for: pitch) else {
                continue
            }

            // Pixel height uses the CURRENT BPM so the rectangle's visual
            // length stays proportional to its on-screen scroll speed — the
            // bottom must still cross the hit line exactly at `hitBeat`
            // regardless of tempo.
            let bpm = max(currentBPM, 30)
            let lengthInPixels = max(20, CGFloat(lengthBeats * 60.0 / Double(bpm)) * pixelsPerSecond)
            let noteWidth = max(8, laneWidth - 6)
            let node = SKShapeNode(rectOf: CGSize(width: noteWidth, height: lengthInPixels), cornerRadius: 8)
            node.fillColor = SKColor(red: 0.84, green: 0.16, blue: 0.16, alpha: 1.0) // RH coral
            node.strokeColor = .clear
            node.position = CGPoint(x: laneWidth * (CGFloat(lane) + 0.5), y: size.height + 200)
            node.alpha = 0
            node.zPosition = 5
            addChild(node)

            scheduled.append(ScheduledNote(hitBeat: hitBeat, lengthBeats: lengthBeats, lane: lane, node: node))
        }
        maxHitBeat = scheduled.map(\.hitBeat).max() ?? 0
    }

    /// Kept as a no-op for API compatibility. Stop / restart is now fully
    /// derived from `playStartedAt` + `accumulatedBeforePause` — when both
    /// are reset to nil/0 by `PlayerViewModel.stopPlaying`, `update` hides
    /// every note on the next frame.
    func reset() {}

    // MARK: - Frame update

    override func update(_ currentTime: TimeInterval) {
        // Stopped (or pre-first-Play): hide everything.
        guard playStartedAt != nil || accumulatedBeforePause > 0 else {
            for note in scheduled where note.node.alpha != 0 {
                note.node.alpha = 0
            }
            lastBeatTocked = -1
            return
        }

        let elapsed = elapsedSeconds
        // Fresh play / replay: elapsed jumps backward. Un-pop every note and
        // reset its visual state so the song can be played again.
        if elapsed + 0.25 < lastElapsed {
            poppedNodes.removeAll()
            lastBeatTocked = -1
            for note in scheduled {
                note.node.removeAllActions()
                note.node.setScale(1)
                note.node.alpha = 0
            }
            endFired = false
        }
        lastElapsed = elapsed

        let bpm = max(currentBPM, 30)
        let beatDuration = 60.0 / Double(bpm)
        let elapsedBeats = elapsed / beatDuration

        // Metronome beat — fired off the SAME clock as the blocks below, so the
        // tock lands exactly when a note crosses the line. One tock per beat.
        // Beats 0…leadIn-1 tick during the run-up — an audible count-in.
        let currentBeat = Int(elapsedBeats)
        if beatsEnabled && currentBeat > lastBeatTocked {
            lastBeatTocked = currentBeat
            onBeat?()
        }

        // End of song: last bar has fallen past the line + a short tail.
        let songEndBeat = maxHitBeat + HitJudge.leadInBeats + 2
        if !endFired, !scheduled.isEmpty, elapsedBeats > songEndBeat {
            endFired = true
            onSongEnd?()
        }

        for note in scheduled {
            // A celebrated note is mid-pop — leave its scale/alpha to the action.
            if poppedNodes.contains(ObjectIdentifier(note.node)) { continue }

            // Lead-in: shift every bar later so note one has fall-time (the
            // run-up). Must match HitJudge.leadInBeats so blocks + judging agree.
            let beatsUntilHit = note.hitBeat + HitJudge.leadInBeats - elapsedBeats
            let timeUntilHit = beatsUntilHit * beatDuration
            let lengthInSeconds = note.lengthBeats * beatDuration
            let lengthInPixels = CGFloat(lengthInSeconds) * pixelsPerSecond

            // Off-screen window: still above the top (>leadTime away) or fully
            // past the hit line (half a second below).
            if timeUntilHit > leadTime || (timeUntilHit + lengthInSeconds) < -0.5 {
                if note.node.alpha != 0 { note.node.alpha = 0 }
                continue
            }
            note.node.alpha = 1
            // Center Y so the rectangle's BOTTOM crosses y=0 exactly at hitBeat.
            let centerY = lengthInPixels / 2 + CGFloat(timeUntilHit) * pixelsPerSecond
            note.node.position = CGPoint(x: note.node.position.x, y: centerY)
        }
    }

    // MARK: - Hit juice

    /// Celebrate a judged press: pop the note nearest the line in `lane`, burst
    /// particles, escalate with `combo`. MISS does nothing (soft — never
    /// punished). Honors Reduce Motion. Spec: hit-juice-spec.md.
    func registerHit(lane: Int, judgment: HitJudgment, combo: Int) {
        guard judgment != .miss else { return }

        let node = scheduled
            .filter {
                $0.lane == lane
                    && $0.node.alpha > 0.5
                    && !poppedNodes.contains(ObjectIdentifier($0.node))
            }
            .min { abs($0.node.position.y) < abs($1.node.position.y) }?
            .node
        guard let node else { return }

        let reduced = UIAccessibility.isReduceMotionEnabled
        let perfect = (judgment == .perfect)
        popNote(node, perfect: perfect, reduced: reduced)

        guard !reduced else { return }
        let laneWidth = size.width / CGFloat(laneCount)
        let point = CGPoint(x: laneWidth * (CGFloat(lane) + 0.5), y: 10)
        let base = perfect ? 10 : 6
        let bonus = min(max(combo - 1, 0), 6)                 // streak adds up to +6
        emitSparkles(at: point, count: min(base + bonus, 14), gold: perfect || combo >= 6)
    }

    private func popNote(_ node: SKShapeNode, perfect: Bool, reduced: Bool) {
        poppedNodes.insert(ObjectIdentifier(node))
        node.removeAllActions()
        if reduced {
            node.run(.fadeOut(withDuration: 0.18))            // calm, scale-free
            return
        }
        let squash = SKAction.scaleX(to: 1.15, y: 0.8, duration: 0.07)
        squash.timingMode = .easeOut
        let hitPause = SKAction.wait(forDuration: 0.045)      // freeze target only (Sakurai)
        let pop = SKAction.group([
            SKAction.scale(to: perfect ? 1.45 : 1.3, duration: 0.15),
            SKAction.fadeOut(withDuration: 0.15)
        ])
        pop.timingMode = .easeOut
        node.run(.sequence([squash, hitPause, pop]))
    }

    private func emitSparkles(at point: CGPoint, count: Int, gold: Bool) {
        let coral = SKColor(red: 0.97, green: 0.45, blue: 0.30, alpha: 1)
        let goldColor = SKColor(red: 1.0, green: 0.82, blue: 0.32, alpha: 1)
        for _ in 0..<count {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4.5))
            dot.fillColor = (gold && Bool.random()) ? goldColor : coral
            dot.strokeColor = .clear
            dot.position = point
            dot.zPosition = 20
            addChild(dot)
            let angle = CGFloat.random(in: 0 ..< (2 * .pi))
            let dist = CGFloat.random(in: 18...42)
            let move = SKAction.move(
                by: CGVector(dx: cos(angle) * dist, dy: sin(angle) * dist + 14),
                duration: 0.3
            )
            move.timingMode = .easeOut
            dot.run(.sequence([
                .group([move, .fadeOut(withDuration: 0.3)]),
                .removeFromParent()
            ]))
        }
    }
}
