import XCTest

/// B26 (#37) — the result screen's next-song handoff card. Uses the DEBUG
/// `-b26-demo-result-stars` hook so the result screen appears seconds after
/// a song opens instead of after a full ~40 s play-through.
final class NextSongHandoffUITests: XCTestCase {

    /// Result → handoff card exists → tap → the player shows the NEW song.
    /// The card's accessibility label carries the suggested title ("Play X
    /// next"), so the assertion follows whatever the picker chose — the test
    /// stays correct however much progress earlier test runs persisted.
    func testHandoffCardTapSwitchesToTheNextSong() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-b26-demo-result-stars", "2",
        ]
        app.launch()

        let twinkle = app.staticTexts["Twinkle Twinkle Little Star"].firstMatch
        XCTAssertTrue(twinkle.waitForExistence(timeout: 10), "Twinkle card on home screen")
        twinkle.tap()

        // Demo hook finishes the song ~1 s in; card springs in after the stars.
        let handoffCard = app.buttons["NextSongHandoffCard"].firstMatch
        XCTAssertTrue(handoffCard.waitForExistence(timeout: 15),
                      "handoff card must appear on the result screen")

        // "Play <title> next" → <title>
        let label = handoffCard.label
        XCTAssertTrue(label.hasPrefix("Play ") && label.hasSuffix(" next"),
                      "handoff card label should advertise the next song, got: \(label)")
        let nextTitle = String(label.dropFirst("Play ".count).dropLast(" next".count))
        XCTAssertNotEqual(nextTitle, "Twinkle Twinkle Little Star",
                          "the card must never suggest the song just played")

        attachScreenshot(name: "b26-handoff-hero")

        handoffCard.tap()

        // One tap → the player swapped to the suggested song (fresh session).
        let newTitle = app.navigationBars[nextTitle].firstMatch
        XCTAssertTrue(newTitle.waitForExistence(timeout: 10),
                      "player must show the handed-off song's title after the tap")
        XCTAssertFalse(app.buttons["NextSongHandoffCard"].exists,
                       "result overlay must be gone after the handoff")
    }

    /// Clean 3/3 on the ladder song: the climb keeps the headline CTA and the
    /// handoff card sits secondary below it — both on screen, neither fighting.
    func testClimbOfferedVariantShowsCardBelowClimbCTA() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-hasCompletedOnboarding", "YES",
            "-b26-demo-result-stars", "3",
        ]
        app.launch()

        let salta = app.staticTexts["Plim Plim (Salta l'Esquirol)"].firstMatch
        XCTAssertTrue(salta.waitForExistence(timeout: 10), "Salta card on home screen")
        salta.tap()

        let handoffCard = app.buttons["NextSongHandoffCard"].firstMatch
        XCTAssertTrue(handoffCard.waitForExistence(timeout: 15),
                      "handoff card must appear alongside the climb offer")

        // The climb CTA ("Faster!" from rung 1, or "Lights off!" higher up)
        // must still be there — the handoff card never replaces it.
        let climb = app.buttons["Faster!"].exists ? app.buttons["Faster!"] : app.buttons["Lights off!"]
        XCTAssertTrue(climb.firstMatch.exists, "climb CTA must survive the handoff card")

        // Secondary placement: the card sits BELOW the climb CTA.
        XCTAssertGreaterThan(handoffCard.frame.minY, climb.firstMatch.frame.minY,
                             "with a climb on offer the handoff card is secondary, below it")

        attachScreenshot(name: "b26-handoff-climb-variant")
    }

    private func attachScreenshot(name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
