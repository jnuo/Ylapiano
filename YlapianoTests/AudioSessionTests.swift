import AVFoundation
import XCTest

@testable import Ylapiano

/// B6 (#14) — ONE audio session, engine-routed count-in. Greppable guards in
/// the `MicFreeTests` style: scans the app source tree on the host (simulator
/// tests run natively, so `#filePath` reaches the repo).
///
/// Guard 1: every `AVAudioSession` MUTATION lives in `AudioSession.swift`.
/// Components that grew their own `setCategory` / `setActive` are exactly how
/// the old session races happened (and how the mic-era `.playAndRecord`
/// lingered until B5 found it). Reading the session (e.g. the latency log in
/// `PianoSampler`) stays allowed — only mutation is fenced.
///
/// Guard 2: no `AudioServicesPlaySystemSound` anywhere in the app. System
/// sounds play at RINGER volume and ignore the `.playback` session, so the
/// count-in tock could blast over a media-volume piano (or vanish with a
/// muted ringer while the piano keeps sounding). Every tock now routes
/// through the shared `AVAudioEngine` (`PianoSampler.playTock` /
/// `playCountIn`).
final class SingleAudioSessionTests: XCTestCase {

    /// Repo root, derived from this file's path (`YlapianoTests/AudioSessionTests.swift`).
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // AudioSessionTests.swift
        .deletingLastPathComponent()   // YlapianoTests/

    private static let appSourceDir = repoRoot.appendingPathComponent("Ylapiano")

    /// The one file allowed to mutate the shared `AVAudioSession`.
    private static let sessionOwner = "AudioSession.swift"

    /// Every regular file in the app target's source tree.
    private static func appFiles() throws -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: appSourceDir, includingPropertiesForKeys: [.isRegularFileKey]) else {
            XCTFail("Cannot enumerate \(appSourceDir.path)")
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { url in
            (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
    }

    /// Session-mutating calls appear ONLY in AudioSession.swift.
    func testOnlyAudioSessionFileMutatesTheSharedSession() throws {
        let mutators = [
            "setCategory(",
            "setActive(",
            "setPreferredSampleRate(",
            "setPreferredIOBufferDuration(",
        ]
        for url in try Self.appFiles() where url.lastPathComponent != Self.sessionOwner {
            guard url.pathExtension == "swift",
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for token in mutators where text.contains(token) {
                XCTFail("\(url.lastPathComponent) mutates the shared AVAudioSession ('\(token)') — only \(Self.sessionOwner) may. Call AudioSession.configurePlayback() instead.")
            }
        }
    }

    /// The session owner itself still configures `.playback` (the guard above
    /// would also pass if session config were deleted outright — this pins the
    /// one legitimate configuration in place).
    func testAudioSessionOwnerConfiguresPlayback() throws {
        let owner = Self.appSourceDir
            .appendingPathComponent("Audio")
            .appendingPathComponent(Self.sessionOwner)
        let text = try String(contentsOf: owner, encoding: .utf8)
        XCTAssertTrue(text.contains("setCategory(.playback"),
                      "AudioSession.swift must configure the .playback category")
        XCTAssertTrue(text.contains("setActive(true)"),
                      "AudioSession.swift must activate the session")
    }

    /// No ringer-volume system sounds anywhere — tocks go through the engine.
    func testNoSystemSoundsInAppSources() throws {
        for url in try Self.appFiles() {
            guard url.pathExtension == "swift",
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if text.contains("AudioServicesPlaySystemSound") {
                XCTFail("\(url.lastPathComponent) plays a system sound (ringer volume, ignores the .playback session) — route it through PianoSampler's engine instead.")
            }
        }
    }
}

/// The count-in scheduling math — pure frame arithmetic, no engine needed.
final class CountInTests: XCTestCase {

    /// The count-in is the song's lead-in: 4 beats = two bars of 2/4, exactly
    /// `HitJudge.leadInBeats` — the run-up the falling notes are already
    /// shifted by, so the last count beat hands off to beat 0 of the song.
    func testCountInBeatsMatchTheLeadIn() {
        XCTAssertEqual(CountIn.beats, 4)
        XCTAssertEqual(Double(CountIn.beats), HitJudge.leadInBeats,
                       "count-in length must match the falling-notes lead-in")
    }

    /// At 60 BPM / 48 kHz a beat is exactly one second of frames.
    func testFrameOffsetsAt60BPM() {
        let offsets = CountIn.frameOffsets(bpm: 60, sampleRate: 48_000)
        XCTAssertEqual(offsets, [0, 48_000, 96_000, 144_000])
    }

    /// Tempo-scaled: doubling the BPM halves the spacing.
    func testFrameOffsetsAt120BPM() {
        let offsets = CountIn.frameOffsets(bpm: 120, sampleRate: 48_000)
        XCTAssertEqual(offsets, [0, 24_000, 48_000, 72_000])
    }

    /// Sample-rate aware — offsets are frames, not seconds.
    func testFrameOffsetsFollowSampleRate() {
        let offsets = CountIn.frameOffsets(bpm: 60, sampleRate: 44_100)
        XCTAssertEqual(offsets, [0, 44_100, 88_200, 132_300])
    }

    /// Degenerate BPM clamps to 30 (same floor as the scene / HitJudge) —
    /// never a divide-by-zero or a negative interval.
    func testBPMClampsAt30() {
        let offsets = CountIn.frameOffsets(bpm: 0, sampleRate: 48_000)
        XCTAssertEqual(offsets, CountIn.frameOffsets(bpm: 30, sampleRate: 48_000))
        XCTAssertEqual(offsets[1], 96_000)   // 30 BPM → 2 s per beat
    }
}
