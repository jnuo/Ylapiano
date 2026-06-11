import XCTest
@testable import Ylapiano

final class MascotAssetTests: XCTestCase {

    // B7: the chibi Pim still pack ships in the asset catalog.
    // MascotPointing has no call site yet — staged for B8 (Pim-led tutorial)
    // and B9 (home header) so the whole pack comes from one canon session.
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
