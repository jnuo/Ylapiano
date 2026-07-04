import XCTest

/// B20 (#20) — the store-capture harness over the `-screenshotState` seed
/// mechanism. Skipped in the normal gate; run on demand with:
///
///   xcodebuild test … -only-testing:YlapianoUITests/StoreScreenshotsUITests \
///     TEST_RUNNER_B20_SEED_SCREENSHOTS=1 \
///     TEST_RUNNER_B20_SEED_SCREENSHOT_DIR=$HOME/Downloads/ylapiano-b20-seeds
///
/// (The `TEST_RUNNER_` prefix is what forwards a variable into the simulator
/// test-runner process — a plain shell export never arrives there.)
///
/// For clean store frames, override the status bar first (documented in
/// product/store-config.md):
///
///   xcrun simctl status_bar <udid> override --time "9:41" --batteryLevel 100
///
/// One launch per shot — each seeded state is a fresh, deterministic
/// process. TR variants ride the same profiles with `-AppleLanguages (tr)`.
final class StoreScreenshotsUITests: XCTestCase {

    private var outputDir: URL {
        let raw = ProcessInfo.processInfo.environment["B20_SEED_SCREENSHOT_DIR"]
            ?? NSTemporaryDirectory()
        return URL(fileURLWithPath: (raw as NSString).expandingTildeInPath, isDirectory: true)
    }

    private func skipUnlessRequested() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["B20_SEED_SCREENSHOTS"] == "1",
                          "screenshot capture only — set B20_SEED_SCREENSHOTS=1 to run")
    }

    private func makeApp(profile: String, turkish: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-screenshotState", profile,
            "-hasCompletedOnboarding", "YES",
        ]
        if turkish {
            app.launchArguments += ["-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        }
        return app
    }

    private func saveScreenshot(_ name: String) throws {
        let dir = outputDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let shot = XCUIScreen.main.screenshot()
        try shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// (a) Library grid with the designed star spread; Pim frozen static.
    func testCaptureHomeGridWithStarSpread() throws {
        try skipUnlessRequested()
        let app = makeApp(profile: "home")
        app.launch()

        let twinkle = app.staticTexts["Twinkle Twinkle Little Star"].firstMatch
        XCTAssertTrue(twinkle.waitForExistence(timeout: 10), "seeded home grid must appear")
        sleep(1)   // let the grid + seeded stars settle (no pop on cold launch)
        try saveScreenshot("1-home-en")
    }

    /// (b) Frozen mid-play falling-notes moment on Old MacDonald — its
    /// opening phrase spreads notes across five lanes, the strongest frame
    /// in the catalog. The seed freezes the shared clock, so Pause chrome
    /// is up and the notes hold position.
    func testCaptureFrozenMidPlayMoment() throws {
        try skipUnlessRequested()
        let app = makeApp(profile: "playing")
        app.launch()

        let song = app.staticTexts["Old MacDonald"].firstMatch
        XCTAssertTrue(song.waitForExistence(timeout: 10), "home must appear")
        song.tap()

        // The freeze lands ~0.8 s after the player appears; isPlaying flips
        // true, which mounts the kid top bar's Pause — our "frozen" signal.
        let pause = app.buttons["Pause"].firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 10), "frozen mid-play state must be live")
        sleep(2)   // rotation + stage fully settled; clock is frozen, nothing moves
        try saveScreenshot("2-playing-en")
    }

    /// (c) 3-star result on the ladder song, handoff card visible, Pim on
    /// the static pose (no looping clip under the seed).
    func testCaptureThreeStarResultWithHandoff() throws {
        try skipUnlessRequested()
        let app = makeApp(profile: "result")
        app.launch()

        let plimPlim = app.staticTexts["Plim Plim (Jump, Little Squirrel)"].firstMatch
        XCTAssertTrue(plimPlim.waitForExistence(timeout: 10), "home must appear")
        plimPlim.tap()

        let handoffCard = app.buttons["NextSongHandoffCard"].firstMatch
        XCTAssertTrue(handoffCard.waitForExistence(timeout: 15), "result screen must appear")
        sleep(2)   // star reveal + burst are one-shot; wait until fully settled
        try saveScreenshot("3-result-en")
    }

    /// (d) TR proof shot — the same `home` profile with the Turkish locale
    /// injected, per the B13 pattern.
    func testCaptureHomeGridInTurkish() throws {
        try skipUnlessRequested()
        let app = makeApp(profile: "home", turkish: true)
        app.launch()

        let twinkle = app.staticTexts["Küçük Yıldız"].firstMatch
        XCTAssertTrue(twinkle.waitForExistence(timeout: 10), "TR home must show Küçük Yıldız")
        sleep(1)
        try saveScreenshot("4-home-tr")
    }
}
