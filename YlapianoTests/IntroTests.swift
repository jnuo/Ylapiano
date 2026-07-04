import AVFoundation
import SwiftUI
import XCTest
@testable import Ylapiano

/// #56 (B31) — guards for the cold-launch intro.
///
/// What's honestly testable: the once-per-launch gate, the timing contract
/// (one loop pass, seam-aligned exit, instant skip), both render branches
/// (animated / Reduce Motion), the bundled clip existing and matching the
/// design, and the wiring in `ContentView` (home mounted underneath, intro
/// as a skippable overlay). The look itself is reviewed by eye — see the
/// PR's recorded clip.
final class IntroTests: XCTestCase {

    /// Repo root, derived from this file's path — same greppable-guard
    /// pattern as `PimIdleTests` / `ArtSystemTests`.
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // IntroTests.swift
        .deletingLastPathComponent()   // YlapianoTests/

    private static func appSource(_ relative: String) throws -> String {
        try String(
            contentsOf: repoRoot.appendingPathComponent("Ylapiano").appendingPathComponent(relative),
            encoding: .utf8
        )
    }

    override func tearDown() {
        IntroGate.reset()
        super.tearDown()
    }

    // MARK: - Once-per-launch gate

    func testIntroShowsExactlyOncePerProcessLaunch() {
        IntroGate.reset()
        XCTAssertTrue(IntroGate.consumeShouldShow(arguments: []),
                      "a cold launch must show the intro")
        XCTAssertFalse(IntroGate.consumeShouldShow(arguments: []),
                       "the intro must show at most once per process launch")
        XCTAssertTrue(IntroGate.hasShownThisLaunch)
    }

    func testUITestLaunchesSkipTheIntro() {
        IntroGate.reset()
        XCTAssertFalse(
            IntroGate.consumeShouldShow(arguments: ["-hasCompletedOnboarding", "YES"]),
            "UI-test launches (the only launches carrying -hasCompletedOnboarding) must not lose 4 s / their first tap to the intro"
        )
        XCTAssertFalse(IntroGate.consumeShouldShow(arguments: []),
                       "a skipped intro still counts as consumed for this launch")
    }

    // MARK: - Timing contract

    func testIntroTimingContract() {
        // ~3 s on screen per the issue; exactly one pass of the 4 s loop so
        // the exit lands on the seam frame.
        XCTAssertTrue((3.0...4.5).contains(IntroDesign.autoAdvanceSeconds),
                      "the intro must auto-advance after roughly one loop pass")
        XCTAssertEqual(IntroDesign.autoAdvanceSeconds, IntroDesign.loopSeconds,
                       "auto-advance should land on the loop seam, not mid-bounce")
        XCTAssertLessThanOrEqual(IntroDesign.fadeOutSeconds, 0.3,
                                 "the hand-off to home is a beat, not a scene")
        XCTAssertTrue((1...4).contains(IntroDesign.dingCount),
                      "a few soft notes, not a fanfare")
        XCTAssertEqual(IntroDesign.dingBeatSeconds, 0.5,
                       "dings ride the clip's 120 BPM bounce beat")
    }

    // MARK: - Bundled clip

    func testIntroClipIsBundledAndMatchesTheDesign() async throws {
        let url = try XCTUnwrap(IntroDesign.videoURL,
                                "PimIntro.mp4 is missing from the app bundle")
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        XCTAssertEqual(duration, IntroDesign.loopSeconds, accuracy: 0.1,
                       "the bundled clip must be the \(IntroDesign.loopSeconds)s loop the design specifies")
        let size = try FileManager.default
            .attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        XCTAssertLessThan(size, 5_000_000, "the intro clip must stay a small bundle add (≤5 MB)")
    }

    // MARK: - Both branches render

    @MainActor
    func testAnimatedAndReduceMotionBranchesRender() {
        for reduceMotion in [false, true] {
            let host = UIHostingController(
                rootView: IntroView(reduceMotionOverride: reduceMotion, onFinish: {})
            )
            host.view.frame = CGRect(x: 0, y: 0, width: 600, height: 800)
            host.view.layoutIfNeeded()
            XCTAssertNotNil(host.view, "IntroView failed to render (reduceMotion: \(reduceMotion))")
            XCTAssertGreaterThan(host.sizeThatFits(in: CGSize(width: 600, height: 800)).width, 0)
        }
        // The Reduce Motion branch's canon still must exist.
        XCTAssertNotNil(UIImage(named: "MascotGreeting"), "intro's static fallback still is missing")
    }

    // MARK: - Contract + wiring guards (greppable, like PimIdleTests)

    /// Tap-anywhere skip, idempotent finish, Reduce Motion honored, and a
    /// muted player (intro sound is the shared engine's lane, not the clip).
    func testIntroKeepsItsContract() throws {
        let intro = try Self.appSource("Views/IntroView.swift")
        XCTAssertTrue(intro.contains("onTapGesture"), "tap anywhere must skip the intro")
        XCTAssertTrue(intro.contains("contentShape(Rectangle())"),
                      "the WHOLE screen must be tappable, not just the drawn pixels")
        XCTAssertTrue(intro.contains("guard !finished"),
                      "a tap racing the auto-advance must finish exactly once")
        XCTAssertTrue(intro.contains("accessibilityReduceMotion"), "the intro must honor Reduce Motion")
        XCTAssertTrue(intro.contains("isMuted = true"),
                      "the clip plays muted — notes come from the shared engine")
    }

    /// `ContentView` hosts the intro as a cold-launch overlay with home
    /// mounted underneath (seeding continues; zero time-to-interactive cost).
    func testContentViewHostsTheIntroOverlay() throws {
        let content = try Self.appSource("ContentView.swift")
        XCTAssertTrue(content.contains("IntroGate.consumeShouldShow()"),
                      "ContentView lost the once-per-launch intro gate (#56)")
        XCTAssertTrue(content.contains("IntroView(sampler:"),
                      "ContentView lost the intro overlay (#56)")
        XCTAssertTrue(content.contains("zIndex(1)"),
                      "the intro must overlay home, not replace it — seeding continues underneath")
    }
}
