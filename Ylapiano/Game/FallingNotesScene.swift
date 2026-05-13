import SpriteKit

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
            return
        }

        let bpm = max(currentBPM, 30)
        let beatDuration = 60.0 / Double(bpm)
        let elapsedBeats = elapsedSeconds / beatDuration

        for note in scheduled {
            let beatsUntilHit = note.hitBeat - elapsedBeats
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
}
