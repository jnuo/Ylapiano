import XCTest

/// B10 (#22) — Kid Mode player: the surface a 5-year-old sees has ONE big
/// obvious control (Play) and nothing an accidental tap can break. The
/// adult-dense toolbar (BPM, toggles, pickers, edit) lives behind the
/// press-and-hold grown-up gate.
final class KidModePlayerUITests: XCTestCase {

    private func launchToPlayer(extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"] + extraArguments
        app.launch()

        let card = app.staticTexts["Twinkle Twinkle Little Star"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Twinkle card on home screen")
        card.tap()
        return app
    }

    /// The player shows exactly the kid surface: big Play, the gate, back —
    /// and none of the old adult toolbar. A quick kid tap on the gate does
    /// nothing. During play the only added control is Pause.
    func testKidSurfaceShowsOnlyPlayAndGate() throws {
        let app = launchToPlayer()

        let bigPlay = app.buttons["BigPlayButton"].firstMatch
        XCTAssertTrue(bigPlay.waitForExistence(timeout: 10), "one big Play, center stage")

        let gate = app.otherElements["GrownUpGateButton"].firstMatch
        let gateFallback = app.descendants(matching: .any)["GrownUpGateButton"].firstMatch
        XCTAssertTrue(gate.waitForExistence(timeout: 5) || gateFallback.exists,
                      "the grown-up gate is present (but inert to taps)")

        // The adult toolbar is GONE from the kid surface.
        XCTAssertFalse(app.staticTexts["BPM"].exists, "no BPM stepper in kid reach")
        XCTAssertFalse(app.buttons["Play Piano"].exists, "no sound toggles in kid reach")
        XCTAssertFalse(app.switches["Play Piano"].exists)
        XCTAssertFalse(app.buttons["Metronome"].exists)
        XCTAssertFalse(app.buttons["Do Re Mi"].exists, "no notation picker in kid reach")
        XCTAssertFalse(app.buttons["Edit Song"].exists, "no edit path in kid reach")
        XCTAssertFalse(app.navigationBars.buttons["Save"].exists)

        // A kid-style quick tap on the gate opens NOTHING.
        (gate.exists ? gate : gateFallback).tap()
        XCTAssertFalse(app.staticTexts["Grown-ups"].waitForExistence(timeout: 2),
                       "a quick tap must never open the grown-ups drawer")

        // Start the song — during play: stage + keyboard + Pause, still no
        // adult controls.
        bigPlay.tap()
        let pause = app.buttons["Pause"].firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 15), "Pause appears once playing (post count-in)")
        XCTAssertFalse(app.staticTexts["BPM"].exists)
        XCTAssertFalse(app.buttons["Edit Song"].exists)

        attachScreenshot(name: "b10-kid-surface-playing")

        // Pause → the big button returns as Resume; nothing was lost.
        pause.tap()
        XCTAssertTrue(app.buttons["Resume"].firstMatch.waitForExistence(timeout: 5),
                      "pausing brings the one big control back as Resume")
    }

    /// A deliberate 2.5 s hold on the gate opens the grown-ups drawer with
    /// the relocated adult controls (B5's UI-test pattern).
    func testHoldGateOpensGrownUpsDrawer() throws {
        let app = launchToPlayer()

        let gate = app.otherElements["GrownUpGateButton"].firstMatch
        let target = gate.waitForExistence(timeout: 10)
            ? gate
            : app.descendants(matching: .any)["GrownUpGateButton"].firstMatch
        XCTAssertTrue(target.exists, "gate present on the kid surface")

        target.press(forDuration: 3.2)

        XCTAssertTrue(app.staticTexts["Grown-ups"].waitForExistence(timeout: 5),
                      "a held press opens the grown-ups drawer")
        XCTAssertTrue(app.staticTexts["BPM"].firstMatch.exists, "BPM control moved into the drawer")
        XCTAssertTrue(app.switches["Play Piano"].firstMatch.exists, "sound toggles moved into the drawer")
        XCTAssertTrue(app.buttons["Edit Song"].firstMatch.exists, "edit entry moved into the drawer")

        attachScreenshot(name: "b10-adult-drawer")

        // Done closes it; the kid surface returns intact.
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["BigPlayButton"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["BPM"].exists)
    }

    /// Deterministic capture of the in-flight hold state via the DEBUG
    /// `-b10-gate-demo-progress` hook (same convention as
    /// `-b26-demo-result-stars`): the ring renders frozen mid-hold.
    func testGateMidHoldProgressRing() throws {
        let app = launchToPlayer(extraArguments: ["-b10-gate-demo-progress", "0.55"])

        XCTAssertTrue(app.buttons["BigPlayButton"].firstMatch.waitForExistence(timeout: 10))
        attachScreenshot(name: "b10-gate-midhold")
    }

    private func attachScreenshot(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
