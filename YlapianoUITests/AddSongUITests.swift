import XCTest

final class AddSongUITests: XCTestCase {

    func testAddCustomSongViaQuickInput() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "YES"]
        app.launch()

        app.buttons["Add Song"].tap()

        let titleField = app.textFields["Song Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Deniz Demo Song")

        let quickInput = app.textFields["Do Do Sol Sol La La Sol"]
        quickInput.tap()
        quickInput.typeText("Do Re Mi Fa Sol La Si")
        app.buttons["Add as Quarter Notes"].tap()

        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Deniz Demo Song"].waitForExistence(timeout: 5),
                      "new song card should appear on the home screen")
        sleep(2) // hold the final frame for the recording
    }
}
