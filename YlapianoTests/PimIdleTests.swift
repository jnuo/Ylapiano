import SwiftUI
import XCTest
@testable import Ylapiano

/// #38 (B27) — guards for Pim's home-screen idle.
///
/// What's honestly testable here: the motion contract stays inside Diego's
/// restraint bar, both branches (animated / Reduce Motion) actually render,
/// the home header hosts the idle, and the idle keeps its lane — no timers,
/// no sound, no card motion. The look itself is reviewed by eye (see the
/// PR's recorded clip), not asserted.
final class PimIdleTests: XCTestCase {

    /// Repo root, derived from this file's path — same greppable-guard
    /// pattern as `ArtSystemTests` / `MicFreeTests`.
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // PimIdleTests.swift
        .deletingLastPathComponent()   // YlapianoTests/

    private static func appSource(_ relative: String) throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent("Ylapiano").appendingPathComponent(relative),
            encoding: .utf8
        )
    }

    // MARK: - Motion contract (Diego's restraint bar)

    func testIdleMotionStaysRestrained() {
        // Breathe: ≤2% scale, ~2 s ease — visible life, never bounce.
        XCTAssertGreaterThan(PimIdleMotion.breatheScale, 1.0)
        XCTAssertLessThanOrEqual(PimIdleMotion.breatheScale, 1.02, "breathe over 2% reads as bouncing, not breathing")
        XCTAssertTrue((1.5...3.0).contains(PimIdleMotion.breathePeriod), "breathe half-cycle should stay ~2 s")

        // Blink: lands inside the specced 2–4 s loop window.
        XCTAssertGreaterThanOrEqual(PimIdleMotion.blinkInterval.lowerBound, 2.0)
        XCTAssertLessThanOrEqual(PimIdleMotion.blinkInterval.upperBound, 4.0)
        XCTAssertTrue((60...250).contains(PimIdleMotion.blinkClosedMilliseconds), "a blink is a beat, not a nap")

        // Tilt: ≤2°, every ~6–8 s (every 2nd blink of a ≤4 s interval).
        XCTAssertLessThanOrEqual(PimIdleMotion.tiltDegrees, 2.0)
        XCTAssertGreaterThanOrEqual(PimIdleMotion.tiltEveryNthBlink, 2, "tilting on every blink is too busy")
    }

    /// The eyelid overlays must land on Pim's face: normalized coordinates in
    /// the still's upper half, left eye strictly left of (and per the tilted
    /// pose, above) the right, and the two lids never touching.
    func testEyelidGeometryMatchesTheGreetingStill() {
        for eye in [PimIdleMotion.leftEye, PimIdleMotion.rightEye] {
            XCTAssertTrue((0.25...0.75).contains(eye.x), "eye x=\(eye.x) is off Pim's face")
            XCTAssertTrue((0.2...0.5).contains(eye.y), "eye y=\(eye.y) is off Pim's face")
            XCTAssertTrue((0.03...0.12).contains(eye.width), "lid width \(eye.width) is out of scale")
        }
        let left = PimIdleMotion.leftEye, right = PimIdleMotion.rightEye
        XCTAssertLessThan(left.x + left.width / 2, right.x - right.width / 2, "eyelids overlap")
        XCTAssertLessThan(left.y, right.y, "MascotGreeting's head tilt puts the left eye higher")
    }

    // MARK: - Both branches render

    @MainActor
    func testAnimatedAndReduceMotionBranchesRender() {
        for reduceMotion in [false, true] {
            let host = UIHostingController(
                rootView: PimIdleView(reduceMotionOverride: reduceMotion)
                    .frame(width: 116, height: 116)
            )
            host.view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            host.view.layoutIfNeeded()
            XCTAssertNotNil(host.view, "PimIdleView failed to render (reduceMotion: \(reduceMotion))")
            XCTAssertGreaterThan(host.sizeThatFits(in: CGSize(width: 200, height: 200)).width, 0)
        }
        // The still behind the idle must exist — a missing asset renders an
        // empty (but non-crashing) header.
        XCTAssertNotNil(UIImage(named: "MascotGreeting"), "idle's base still is missing")
    }

    // MARK: - Placement + lane guards (greppable, like ArtSystemTests)

    /// The home header hosts the idle in the left slot.
    func testHomeScreenHostsThePimIdleHeader() throws {
        let home = try Self.appSource("Views/HomeScreen.swift")
        XCTAssertTrue(home.contains("PimIdleView("), "HomeScreen lost its Pim idle header (#38)")
        XCTAssertTrue(home.contains("PimIdleHeader"), "the idle header's accessibility identifier is gone")
    }

    /// The idle keeps its lane: no timers or display links (CPU stays
    /// trivial), no sound, no video player, and it never touches the song
    /// cards — B9's star-pop owns card motion.
    func testIdleStaysInItsLane() throws {
        // Grep CODE only — the file's doc comments name the forbidden APIs
        // on purpose (they document why they're banned).
        let idle = try Self.appSource("Views/PimIdleView.swift")
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        for forbidden in ["Timer", "CADisplayLink", "TimelineView",
                          "AVPlayer", "AVAudioPlayer", "AudioSession",
                          "SongCardView", "sampler"] {
            XCTAssertFalse(idle.contains(forbidden), "PimIdleView must not use \(forbidden)")
        }
        XCTAssertTrue(idle.contains("accessibilityReduceMotion"), "the idle must honor Reduce Motion")
    }
}
