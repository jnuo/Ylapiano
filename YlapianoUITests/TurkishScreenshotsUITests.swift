import XCTest

/// B13 (#18) — Turkish verification screenshots. Skipped in the normal gate;
/// run on demand with:
///
///   B13_TR_SCREENSHOTS=1 B13_TR_SCREENSHOT_DIR=~/Downloads/ylapiano-b13-turkish \
///   xcodebuild test … -only-testing:YlapianoUITests/TurkishScreenshotsUITests
///
/// Boots the app with the Turkish locale injected (-AppleLanguages) and saves
/// home / player / result / grown-ups-drawer PNGs to the given directory, so
/// "TR actually renders in the build" is a look, not a claim.
final class TurkishScreenshotsUITests: XCTestCase {

    private var outputDir: URL {
        let raw = ProcessInfo.processInfo.environment["B13_TR_SCREENSHOT_DIR"]
            ?? NSTemporaryDirectory()
        return URL(fileURLWithPath: (raw as NSString).expandingTildeInPath, isDirectory: true)
    }

    private func makeApp(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-AppleLanguages", "(tr)",
            "-AppleLocale", "tr_TR",
        ]
        app.launchArguments += extraArguments
        return app
    }

    private func saveScreenshot(_ name: String) throws {
        let dir = outputDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let shot = XCUIScreen.main.screenshot()
        try shot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
        // Also attach, so the xcresult keeps a copy if the direct write path
        // is unavailable on some runner.
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Home (TR card titles) → player (TR gate + empty-drawer chrome) →
    /// grown-ups drawer (TR adult controls).
    func testCaptureHomePlayerAndDrawerInTurkish() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["B13_TR_SCREENSHOTS"] == "1",
                          "screenshot capture only — set B13_TR_SCREENSHOTS=1 to run")
        let app = makeApp()
        app.launch()

        // Home: under tr the Twinkle card shows its Turkish nursery title.
        let twinkle = app.staticTexts["Küçük Yıldız"].firstMatch
        XCTAssertTrue(twinkle.waitForExistence(timeout: 10), "TR home must show Küçük Yıldız")
        try saveScreenshot("1-home-tr")

        twinkle.tap()
        // Same query + fallback pattern as KidModePlayerUITests.
        let gate = app.otherElements["GrownUpGateButton"].firstMatch
        let gateTarget = gate.waitForExistence(timeout: 10)
            ? gate
            : app.descendants(matching: .any)["GrownUpGateButton"].firstMatch
        XCTAssertTrue(gateTarget.exists, "player gate present")
        XCTAssertTrue(app.staticTexts["Büyükler için basılı tut"].waitForExistence(timeout: 5),
                      "gate label must render in Turkish")
        // Let the stage (spinner → panel) settle before shooting.
        sleep(2)
        try saveScreenshot("2-player-gate-tr")

        // Hold the gate past its 2.5 s threshold → grown-ups drawer. Query
        // the TR title staticText (KidModePlayerUITests' pattern), with a
        // generous wait — the unlock can land a beat late on a loaded sim.
        gateTarget.press(forDuration: 3.2)
        let drawerTitle = app.staticTexts["Büyükler"].firstMatch
        if !drawerTitle.waitForExistence(timeout: 10) {
            gateTarget.press(forDuration: 3.2)   // one retry — first hold can race the stage build
        }
        XCTAssertTrue(drawerTitle.waitForExistence(timeout: 10),
                      "drawer must open after the hold, titled in Turkish")
        try saveScreenshot("3-grownups-drawer-tr")
    }

    /// Result screen on the ladder song: TR rung badge, TR climb CTA, TR
    /// handoff card label — via the B26 demo-result hook.
    func testCaptureResultScreenInTurkish() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["B13_TR_SCREENSHOTS"] == "1",
                          "screenshot capture only — set B13_TR_SCREENSHOTS=1 to run")
        let app = makeApp(extraArguments: ["-b26-demo-result-stars", "3"])
        app.launch()

        let salta = app.staticTexts["Plim Plim (Zıpla Sincap)"].firstMatch
        XCTAssertTrue(salta.waitForExistence(timeout: 10), "TR home must show Plim Plim (Zıpla Sincap)")
        salta.tap()

        let handoffCard = app.buttons["NextSongHandoffCard"].firstMatch
        XCTAssertTrue(handoffCard.waitForExistence(timeout: 15), "result screen must appear")
        XCTAssertTrue(app.buttons["Daha hızlı!"].firstMatch.exists,
                      "climb CTA must render in Turkish")
        try saveScreenshot("4-result-tr")
    }
}
