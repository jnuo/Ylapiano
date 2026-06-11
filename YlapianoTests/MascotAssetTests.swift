import XCTest
@testable import Ylapiano

final class MascotAssetTests: XCTestCase {

    // B7: the chibi Pim still pack ships in the asset catalog.
    func testChibiPimStillPackResolves() {
        XCTAssertNotNil(UIImage(named: "MascotGreeting"), "MascotGreeting imageset missing")
        XCTAssertNotNil(UIImage(named: "MascotPointing"), "MascotPointing imageset missing")
        XCTAssertNotNil(UIImage(named: "MascotCheer"), "MascotCheer imageset missing")
    }

    // B7: the legacy painterly Mascot imageset is retired.
    func testLegacyMascotIsGone() {
        XCTAssertNil(UIImage(named: "Mascot"), "old Mascot.imageset should be retired")
    }
}
