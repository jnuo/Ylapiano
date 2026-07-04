import XCTest
@testable import Ylapiano

/// B17 (#7) — the Grown-Ups corner's facts: support endpoints, the App Store
/// review deep link, the CC0 piano attribution (B23's promise), and the
/// version footer. The gate-required ENTRY is covered by
/// `GrownUpsCornerUITests`; the localization completeness of the corner's
/// copy rides the B13 gates in `LocalizationTests`.
final class GrownUpsCornerTests: XCTestCase {

    // MARK: - Support links

    func testSupportPageIsTheStoreListingSupportURL() {
        // Must match the support URL App Store Connect points at
        // (product/store-listing/privacy-nutrition-label.md).
        XCTAssertEqual(GrownUpsCornerInfo.supportPageURL.absoluteString,
                       "https://www.onurovali.me/ylapiano/support")
        XCTAssertEqual(GrownUpsCornerInfo.supportPageURL.scheme, "https")
    }

    func testSupportMailLinkIsAPreAddressedMailto() {
        let url = GrownUpsCornerInfo.supportMailURL
        XCTAssertEqual(url.scheme, "mailto")
        XCTAssertTrue(url.absoluteString.contains(GrownUpsCornerInfo.supportEmail),
                      "mailto must carry the same address the live support page publishes")
        XCTAssertTrue(url.absoluteString.contains("subject="),
                      "a pre-filled subject routes the mail at a glance")
    }

    // MARK: - Rating deep link

    func testWriteReviewDeepLinkTargetsTheAppStoreReviewSheet() {
        let url = GrownUpsCornerInfo.writeReviewURL
        XCTAssertEqual(url.scheme, "itms-apps", "must open the App Store app, not Safari")
        XCTAssertTrue(url.absoluteString.contains("action=write-review"),
                      "must land on the write-a-review sheet, not the product page")
        XCTAssertTrue(url.absoluteString.contains("id\(GrownUpsCornerInfo.appStoreID)"))
    }

    func testAppStoreIDIsEitherThePlaceholderOrNumeric() {
        // The numeric Apple ID is minted when the ASC app record is created;
        // until then the all-zero placeholder keeps the "Write a review" row
        // hidden (`hasRealAppStoreID`). Whatever lands here must stay numeric
        // or the deep link 404s.
        XCTAssertTrue(GrownUpsCornerInfo.appStoreID.allSatisfy(\.isNumber),
                      "App Store ID must be the numeric ASC Apple ID")
        if !GrownUpsCornerInfo.hasRealAppStoreID {
            XCTAssertTrue(GrownUpsCornerInfo.appStoreID.allSatisfy { $0 == "0" },
                          "placeholder is all zeros by convention")
        }
    }

    // MARK: - Attribution (B23's credit promise)

    /// ATTRIBUTIONS.md promises the CC0 piano is "credited … in the app's
    /// Grown-Ups corner once B17 ships". This pins the credit line — in both
    /// launch locales — to the facts: the SoundFont's name, its project, and
    /// its license.
    func testAttributionCreditNamesTheCC0PianoInBothLocales() throws {
        let key = "Piano sound: Upright Piano KW, recorded from a real Kawai upright piano by the FreePats project. Released under CC0 — thank you."
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()                    // YlapianoTests/
            .deletingLastPathComponent()                    // repo root
            .appendingPathComponent("Ylapiano/Resources/Localizable.xcstrings")
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        )
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        let entry = try XCTUnwrap(strings[key] as? [String: Any],
                                  "the attribution credit line must exist in the catalog")
        let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])

        for lang in ["en", "tr"] {
            let unit = try XCTUnwrap(
                ((localizations[lang] as? [String: Any])?["stringUnit"] as? [String: Any]),
                "attribution must ship in \(lang)"
            )
            let value = try XCTUnwrap(unit["value"] as? String)
            for fact in ["Upright Piano KW", "FreePats", "CC0"] {
                XCTAssertTrue(value.contains(fact),
                              "\(lang) credit line must name '\(fact)'")
            }
        }
    }

    // MARK: - Version footer

    func testVersionFooterReflectsTheBundle() {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        XCTAssertEqual(GrownUpsCornerInfo.appVersion, "\(short ?? "?") (\(build ?? "?"))")
    }
}
