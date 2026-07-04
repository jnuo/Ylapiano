import XCTest

/// B4 (#21) sub-task 3: a non-Salta song launches falling-notes and ends in
/// the stars/Pim result screen (no flat "Great job!" card exists anymore).
final class SongResultUITests: XCTestCase {

    func testTwinkleEndsInResultScreen() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let card = app.staticTexts["Twinkle Twinkle Little Star"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Twinkle card on home screen")
        card.tap()

        let play = app.buttons["Play"].firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 10), "player toolbar Play button")
        play.tap()

        // Count-in (~4s) + 48 beats at 80 BPM (~36s) + end-of-song buffer.
        let replay = app.buttons["Play again"].firstMatch
        XCTAssertTrue(replay.waitForExistence(timeout: 90),
                      "result screen (stars + Pim) after the song runs out")

        XCTAssertFalse(app.staticTexts["Great job!"].exists,
                       "flat completion card must be gone")
        XCTAssertFalse(app.staticTexts["LEARN THE KEYS"].exists,
                       "no ladder rung label on a non-Salta song")

        // B26 (#37): after the stars, the next-song handoff card springs in —
        // the result screen is a bridge to the next song, not a dead-end.
        XCTAssertTrue(app.buttons["NextSongHandoffCard"].firstMatch.waitForExistence(timeout: 10),
                      "next-song handoff card after a real full-song run")

        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
