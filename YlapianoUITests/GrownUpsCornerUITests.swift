import XCTest

/// B17 (#7) — the Grown-Ups corner behind the home screen's hold gate.
///
/// The kid-safety contract, verified end-to-end: a quick tap on the gate does
/// NOTHING; only a deliberate ~2.5 s hold opens the corner. Plus the corner's
/// contents (attribution credit, version footer, support/rating rows).
///
/// The screenshot captures are skipped in the normal gate; run on demand with:
///
///   B17_SHOTS=1 B17_SHOTS_DIR=~/Downloads/ylapiano-b17-grownups \
///   xcodebuild test … -only-testing:YlapianoUITests/GrownUpsCornerUITests
final class GrownUpsCornerUITests: XCTestCase {

    private func makeApp(turkish: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        // -hasCompletedOnboarding also silences the B28 rating engine (its
        // UI-test guard), so the system review dialog can never eat a tap.
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        if turkish {
            app.launchArguments += ["-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        }
        return app
    }

    /// Same query + fallback pattern as KidModePlayerUITests — the home
    /// screen has exactly one gate (the player isn't open).
    private func gate(in app: XCUIApplication) -> XCUIElement {
        let gate = app.otherElements["GrownUpGateButton"].firstMatch
        return gate.waitForExistence(timeout: 10)
            ? gate
            : app.descendants(matching: .any)["GrownUpGateButton"].firstMatch
    }

    private func corner(in app: XCUIApplication) -> XCUIElement {
        let corner = app.otherElements["GrownUpsCorner"].firstMatch
        return corner.exists
            ? corner
            : app.descendants(matching: .any)["GrownUpsCorner"].firstMatch
    }

    /// Hold the gate past its 2.5 s threshold, with one retry — the first
    /// hold can race the home screen settling (TurkishScreenshotsUITests'
    /// validated pattern).
    private func openCorner(in app: XCUIApplication) -> XCUIElement {
        let gateTarget = gate(in: app)
        gateTarget.press(forDuration: 3.2)
        var opened = corner(in: app)
        if !opened.waitForExistence(timeout: 10) {
            gateTarget.press(forDuration: 3.2)
            opened = corner(in: app)
        }
        return opened
    }

    // MARK: - Gate-required entry (the kid-safety contract)

    func testCornerOpensOnlyThroughTheHold() throws {
        let app = makeApp()
        app.launch()

        let gateTarget = gate(in: app)
        XCTAssertTrue(gateTarget.exists, "home screen must show the grown-up gate")

        // A kid-style quick tap must do nothing at all.
        gateTarget.tap()
        XCTAssertFalse(corner(in: app).waitForExistence(timeout: 2),
                       "a quick tap must NOT open the Grown-Ups corner")

        // A deliberate adult hold opens it.
        let opened = openCorner(in: app)
        XCTAssertTrue(opened.waitForExistence(timeout: 10),
                      "a ~2.5 s hold must open the Grown-Ups corner")

        // Contents: the CC0 piano credit (B23's promise) + version footer +
        // the support and rating rows.
        XCTAssertTrue(app.staticTexts["PianoCreditLine"].firstMatch.exists,
                      "the CC0 piano attribution must be visible in the corner")
        XCTAssertTrue(app.staticTexts["VersionFooter"].firstMatch.exists,
                      "the app version footer must be visible in the corner")
        XCTAssertTrue(app.descendants(matching: .any)["SupportLinkRow"].firstMatch.exists,
                      "the support link row must be present")
        XCTAssertTrue(app.descendants(matching: .any)["RateYlapianoRow"].firstMatch.exists,
                      "the rate-Ylapiano row must be present")
    }

    // MARK: - Verification screenshots (on demand)

    private var outputDir: URL {
        let raw = ProcessInfo.processInfo.environment["B17_SHOTS_DIR"]
            ?? NSTemporaryDirectory()
        return URL(fileURLWithPath: (raw as NSString).expandingTildeInPath, isDirectory: true)
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

    func testCaptureCornerInEnglish() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["B17_SHOTS"] == "1",
                          "screenshot capture only — set B17_SHOTS=1 to run")
        let app = makeApp()
        app.launch()
        XCTAssertTrue(openCorner(in: app).waitForExistence(timeout: 10))
        sleep(1)   // let the sheet spring settle
        try saveScreenshot("grownups-corner-en")
    }

    func testCaptureCornerInTurkish() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["B17_SHOTS"] == "1",
                          "screenshot capture only — set B17_SHOTS=1 to run")
        let app = makeApp(turkish: true)
        app.launch()
        XCTAssertTrue(openCorner(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Büyükler"].firstMatch.waitForExistence(timeout: 5),
                      "corner header must render in Turkish")
        sleep(1)
        try saveScreenshot("grownups-corner-tr")
    }
}
