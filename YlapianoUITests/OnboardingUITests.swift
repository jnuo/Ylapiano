import XCTest

/// B5 (#27) — onboarding after the mic deletion: exactly two pages
/// (welcome → ready), no microphone page, no permission ask, honest
/// input copy (on-screen keys or USB MIDI).
final class OnboardingUITests: XCTestCase {

    func testOnboardingIsTwoPagesWithNoMicPage() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasCompletedOnboarding", "NO"]
        app.launch()

        // Page 1: welcome — the input feature line is honest. A paged TabView
        // keeps every page in the hierarchy, so `exists` checks below cover
        // the WHOLE onboarding flow, not just the visible page: no mic page
        // can be hiding off-screen.
        waitHittable(app.staticTexts["Learn piano the fun way!"])
        XCTAssertTrue(app.staticTexts["Play on screen or a USB piano"].exists)
        XCTAssertFalse(app.staticTexts["Listens to your piano playing"].exists,
                       "mic claim must be gone from the welcome page")
        XCTAssertFalse(app.staticTexts["Microphone Access"].exists,
                       "the mic onboarding page must not exist on ANY page")
        XCTAssertFalse(app.buttons["Allow Microphone"].exists,
                       "onboarding must never ask for mic permission")
        saveScreenshot(app, as: "page1-welcome.png")

        // Next goes STRAIGHT to the ready page — no mic page in between —
        // and the ready page carries the finish button. (The handoff to the
        // home screen itself isn't assertable here: the `-hasCompletedOnboarding
        // NO` launch argument overrides the app's own defaults write, so the
        // app can never leave onboarding under this test.)
        app.buttons["Next"].tap()
        waitHittable(app.staticTexts["You're all set!"])
        waitHittable(app.buttons["Let's Go!"])
        saveScreenshot(app, as: "page2-ready.png")
    }

    /// Wait until `element` is actually on screen and tappable — `exists`
    /// alone is true for off-screen pages of a paged TabView, and tapping an
    /// element mid page-swipe animation lands on stale coordinates.
    private func waitHittable(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let hittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [hittable], timeout: timeout), .completed,
                       "\(element) never became hittable")
    }

    /// Attach a named full-screen screenshot to the test result (kept even on
    /// success). Export them with:
    /// `xcrun xcresulttool export attachments --path <xcresult> --output-path <dir>`
    private func saveScreenshot(_ app: XCUIApplication, as name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
