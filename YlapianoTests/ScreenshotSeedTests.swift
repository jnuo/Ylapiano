import XCTest
@testable import Ylapiano

/// B20 (#20) — the screenshot seed mechanism: profile parsing, the legacy
/// demo-hook aliases it consolidates (B9 / B26), the Release guard, and the
/// designed home star spread the B21 library frame shoots.
final class ScreenshotSeedTests: XCTestCase {

    // MARK: - Profile parsing

    func testParsesEachProfileFromScreenshotStateArgument() {
        XCTAssertEqual(ScreenshotSeed.profile(from: ["-screenshotState", "home"], enabled: true), .home)
        XCTAssertEqual(ScreenshotSeed.profile(from: ["-screenshotState", "playing"], enabled: true), .playing)
        XCTAssertEqual(ScreenshotSeed.profile(from: ["-screenshotState", "result"], enabled: true), .result)
    }

    func testParsesProfileAmidOtherLaunchArguments() {
        let args = ["-hasCompletedOnboarding", "YES", "-AppleLanguages", "(tr)",
                    "-screenshotState", "home", "-AppleLocale", "tr_TR"]
        XCTAssertEqual(ScreenshotSeed.profile(from: args, enabled: true), .home)
    }

    func testUnknownProfileNameParsesToNil() {
        XCTAssertNil(ScreenshotSeed.profile(from: ["-screenshotState", "paywall"], enabled: true))
    }

    func testMissingProfileValueParsesToNil() {
        XCTAssertNil(ScreenshotSeed.profile(from: ["-screenshotState"], enabled: true))
    }

    func testNoArgumentParsesToNil() {
        XCTAssertNil(ScreenshotSeed.profile(from: [], enabled: true))
        XCTAssertNil(ScreenshotSeed.profile(from: ["-hasCompletedOnboarding", "YES"], enabled: true))
    }

    // MARK: - Legacy demo-hook aliases (consolidation)

    func testLegacyB9DemoStarsAliasesToHomeProfile() {
        XCTAssertEqual(ScreenshotSeed.profile(from: ["-b9-demo-stars"], enabled: true), .home)
    }

    func testLegacyB26DemoResultStarsAliasesToResultProfile() {
        let args = ["-hasCompletedOnboarding", "YES", "-b26-demo-result-stars", "2"]
        XCTAssertEqual(ScreenshotSeed.profile(from: args, enabled: true), .result)
        XCTAssertEqual(ScreenshotSeed.resultStars(from: args, enabled: true), 2)
    }

    func testLegacyResultStarsClampToThreeAndRejectNonPositive() {
        XCTAssertEqual(
            ScreenshotSeed.resultStars(from: ["-b26-demo-result-stars", "7"], enabled: true), 3)
        // The original hook's `stars > 0` guard: 0 / garbage = no seed at all.
        XCTAssertNil(ScreenshotSeed.profile(from: ["-b26-demo-result-stars", "0"], enabled: true))
        XCTAssertNil(ScreenshotSeed.profile(from: ["-b26-demo-result-stars", "lots"], enabled: true))
    }

    func testResultProfileDefaultsToThreeStarHero() {
        XCTAssertEqual(
            ScreenshotSeed.resultStars(from: ["-screenshotState", "result"], enabled: true), 3)
    }

    func testResultStarsIsNilForNonResultProfiles() {
        XCTAssertNil(ScreenshotSeed.resultStars(from: ["-screenshotState", "home"], enabled: true))
        XCTAssertNil(ScreenshotSeed.resultStars(from: [], enabled: true))
    }

    // MARK: - Release guard (config-conditional)

    /// The `enabled` seam IS the compiled `#if DEBUG || STORE_CAPTURE`
    /// switch: with it false (a Release build), every query ignores the
    /// argument entirely.
    func testDisabledBuildIgnoresEveryArgumentSpelling() {
        XCTAssertNil(ScreenshotSeed.profile(from: ["-screenshotState", "home"], enabled: false))
        XCTAssertNil(ScreenshotSeed.profile(from: ["-screenshotState", "playing"], enabled: false))
        XCTAssertNil(ScreenshotSeed.profile(from: ["-screenshotState", "result"], enabled: false))
        XCTAssertNil(ScreenshotSeed.profile(from: ["-b9-demo-stars"], enabled: false))
        XCTAssertNil(ScreenshotSeed.profile(from: ["-b26-demo-result-stars", "3"], enabled: false))
        XCTAssertNil(ScreenshotSeed.resultStars(from: ["-screenshotState", "result"], enabled: false))
    }

    /// This test target builds Debug, so the compiled switch must be on —
    /// proving `isEnabled` really is wired to the build configuration (and
    /// therefore off in Release, where neither DEBUG nor STORE_CAPTURE is
    /// defined).
    func testIsEnabledReflectsBuildConfiguration() {
        #if DEBUG || STORE_CAPTURE
        XCTAssertTrue(ScreenshotSeed.isEnabled)
        #else
        XCTAssertFalse(ScreenshotSeed.isEnabled)
        #endif
    }

    // MARK: - Designed home star spread (B21 library frame)

    func testHomeStarSpreadCoversTheWholeCatalog() {
        XCTAssertEqual(ScreenshotSeed.homeStarSpread.count,
                       SeedData.createSeedSongs().count,
                       "one designed value per catalog card — update the spread when the catalog moves")
    }

    func testHomeStarSpreadIsAValidMidJourneyMix() {
        let spread = ScreenshotSeed.homeStarSpread
        XCTAssertTrue(spread.allSatisfy { (0...3).contains($0) })
        // The B21 frame plan wants a believable mix of 3/2/1/0 — every tier
        // present, not a flat all-3s brag or an empty grid.
        XCTAssertEqual(Set(spread), Set([0, 1, 2, 3]))
    }

    // MARK: - Frozen mid-play moment

    func testPlayingFreezeLandsInsideTheSongPastTheLeadIn() {
        XCTAssertGreaterThan(ScreenshotSeed.playingFreezeBeats, HitJudge.leadInBeats,
                             "the frozen moment must be past the run-up so notes are on screen")
    }
}
