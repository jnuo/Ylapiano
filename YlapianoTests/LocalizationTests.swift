import XCTest
@testable import Ylapiano

/// B13 (#18) — String Catalog + Turkish.
///
/// Two layers of guarantee:
///  1. CATALOG COMPLETENESS — parses `Localizable.xcstrings` from the repo
///     (via #filePath) and asserts every translatable key carries a complete,
///     non-empty en + tr pair. Turkish is a launch market: a key without
///     Turkish fails the build gate, not App Review.
///  2. BUILD WIRING — asserts the compiled app bundle actually SHIPS the
///     Turkish localization (tr.lproj resolves the catalog values), so the
///     catalog can't silently fall out of the target.
final class LocalizationTests: XCTestCase {

    // MARK: - Catalog parsing

    private struct Catalog {
        let sourceLanguage: String
        /// key → (shouldTranslate, language → (state, value))
        let strings: [String: (shouldTranslate: Bool, units: [String: (state: String, value: String)])]
    }

    private static func loadCatalog() throws -> Catalog {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()                    // YlapianoTests/
            .deletingLastPathComponent()                    // repo root
            .appendingPathComponent("Ylapiano/Resources/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let root = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "Localizable.xcstrings must be a JSON object"
        )
        let source = try XCTUnwrap(root["sourceLanguage"] as? String)
        let rawStrings = try XCTUnwrap(root["strings"] as? [String: Any])

        var strings: [String: (Bool, [String: (String, String)])] = [:]
        for (key, rawEntry) in rawStrings {
            let entry = try XCTUnwrap(rawEntry as? [String: Any], "entry for '\(key)'")
            let shouldTranslate = (entry["shouldTranslate"] as? Bool) ?? true
            var units: [String: (String, String)] = [:]
            if let localizations = entry["localizations"] as? [String: Any] {
                for (lang, rawLoc) in localizations {
                    let loc = try XCTUnwrap(rawLoc as? [String: Any])
                    let unit = try XCTUnwrap(loc["stringUnit"] as? [String: Any],
                                             "'\(key)' [\(lang)] must use a plain stringUnit")
                    let state = try XCTUnwrap(unit["state"] as? String)
                    let value = try XCTUnwrap(unit["value"] as? String)
                    units[lang] = (state, value)
                }
            }
            strings[key] = (shouldTranslate, units)
        }
        return Catalog(sourceLanguage: source, strings: strings)
    }

    // MARK: - 1. Completeness

    func testSourceLanguageIsEnglish() throws {
        XCTAssertEqual(try Self.loadCatalog().sourceLanguage, "en")
    }

    /// Every key has an explicit, non-empty English value.
    func testEveryKeyHasEnglish() throws {
        let catalog = try Self.loadCatalog()
        for (key, entry) in catalog.strings {
            let en = entry.units["en"]
            XCTAssertNotNil(en, "'\(key)' is missing its en value")
            XCTAssertFalse(en?.value.isEmpty ?? true, "'\(key)' has an EMPTY en value")
        }
    }

    /// The B13 bar: every translatable key has a non-empty, finalized Turkish
    /// value. Keys marked shouldTranslate=false (brand, units, solfège) are
    /// exempt by design, not by omission.
    func testEveryTranslatableKeyHasTurkish() throws {
        let catalog = try Self.loadCatalog()
        for (key, entry) in catalog.strings where entry.shouldTranslate {
            let tr = entry.units["tr"]
            XCTAssertNotNil(tr, "'\(key)' has NO Turkish translation")
            XCTAssertFalse(tr?.value.isEmpty ?? true, "'\(key)' has an EMPTY Turkish value")
            XCTAssertEqual(tr?.state, "translated",
                           "'\(key)' Turkish is not finalized (state=\(tr?.state ?? "nil"))")
        }
    }

    /// No localization anywhere may carry an empty value (a needs_review
    /// Spanish entry is fine; an empty string is never fine).
    func testNoEmptyValuesInAnyLanguage() throws {
        let catalog = try Self.loadCatalog()
        for (key, entry) in catalog.strings {
            for (lang, unit) in entry.units {
                XCTAssertFalse(unit.value.isEmpty, "'\(key)' [\(lang)] is empty")
            }
        }
    }

    /// The keys the UI actually renders must exist in the catalog — guards
    /// against key drift between code literals and the hand-authored catalog.
    /// (Every LocalizedStringKey literal in Views/ViewModels appears here or
    /// is a pure format passthrough like "%lld".)
    func testCatalogCoversTheUISurface() throws {
        let expected: Set<String> = [
            // Home
            "Add Song", "MIDI keyboard connected", "No MIDI keyboard connected",
            "Stop preview", "Hear a preview of %@", "%@, %lld of 3 stars",
            "Sync spike",
            // Player + result
            "Pause", "Resume", "Play", "Go!", "Play:", "Nice practicing!",
            "No notes yet", "No notes yet — ask a grown-up to add some.",
            "Play again", "Play %@ next",
            "Learn the keys", "Find the beat", "Play it", "Master it",
            "Faster!", "Lights off!",
            // Grown-up gate + drawer
            "Hold for grown-ups", "Hold to add notes", "Grown-ups", "Done",
            "BPM", "%lld BPM", "Play Piano", "Metronome",
            "Notation", "Do Re Mi", "C D E", "View", "Falling notes",
            "Sheet music", "Edit Song", "MIDI Keyboard", "Connected",
            "Not connected", "Stop Song",
            // Song editor
            "New Song", "Song Title", "Song Info", "Quick Input",
            "Type notes separated by spaces:", "Do Do Sol Sol La La Sol",
            "Add as Quarter Notes", "Add as Eighth Notes", "Notes (%lld)",
            "No notes added yet. Use Quick Input above or tap + below.",
            "Add Note", "Cancel", "Save",
            "Set by the mastery ladder",
            "This song's tempo climbs with the mastery ladder — each rung sets its own speed.",
            // Note row + durations
            "Note", "Oct", "Duration",
            "Whole", "Half", "Quarter", "Eighth",
            "Dotted Half", "Dotted Quarter", "Dotted Eighth",
            // Onboarding + intro
            "Ylapiano", "Learn piano the fun way!", "Follow songs note by note",
            "Play on screen or a USB piano", "Get instant feedback", "Next",
            "You're all set!", "Pick a song and start playing. Have fun!",
            "Let's Go!", "Skip intro",
        ]
        let keys = Set(try Self.loadCatalog().strings.keys)
        let missing = expected.subtracting(keys)
        XCTAssertTrue(missing.isEmpty, "catalog is missing UI keys: \(missing.sorted())")
    }

    // MARK: - 2. Build wiring (the catalog must actually ship)

    /// The compiled app bundle carries a Turkish localization…
    func testAppBundleShipsTurkish() throws {
        XCTAssertTrue(Bundle.main.localizations.contains("tr"),
                      "tr must be in the app's localizations (knownRegions + xcstrings in the target)")
    }

    /// …and resolving through tr.lproj yields the catalog's Turkish values,
    /// not the English fallback — i.e. the xcstrings compiled into the build.
    func testTurkishActuallyResolvesInTheBuiltBundle() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "tr", ofType: "lproj"),
                                 "built app must contain tr.lproj")
        let tr = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(tr.localizedString(forKey: "Add Song", value: nil, table: nil),
                       "Şarkı Ekle")
        XCTAssertEqual(tr.localizedString(forKey: "Hold for grown-ups", value: nil, table: nil),
                       "Büyükler için basılı tut")
        XCTAssertEqual(tr.localizedString(forKey: "Go!", value: nil, table: nil),
                       "Başla!")
        XCTAssertEqual(tr.localizedString(forKey: "Faster!", value: nil, table: nil),
                       "Daha hızlı!")
    }

    /// Spanish still ships (carried from the legacy .strings files).
    func testSpanishStillResolvesInTheBuiltBundle() throws {
        let path = try XCTUnwrap(Bundle.main.path(forResource: "es", ofType: "lproj"),
                                 "built app must contain es.lproj")
        let es = try XCTUnwrap(Bundle(path: path))
        XCTAssertEqual(es.localizedString(forKey: "Add Song", value: nil, table: nil),
                       "Añadir Canción")
    }

    // MARK: - Song titles (data, not catalog — B13 final decisions)

    func testTurkishSeedTitlesStayTurkishEverywhere() {
        // Canonical titles ARE the Turkish titles; no localization entry, so
        // every locale falls back to them.
        XCTAssertEqual(SeedData.localizedTitle(seedID: "kirmizi-balik", locale: Locale(identifier: "en")),
                       "Kırmızı Balık")
        XCTAssertEqual(SeedData.localizedTitle(seedID: "kirmizi-balik", locale: Locale(identifier: "tr")),
                       "Kırmızı Balık")
    }

    func testCatalanSeedTitlesStayCatalanEverywhere() {
        for (seedID, title) in [
            "sol-solet": "Sol Solet",
            "cargol-treu-banya": "Cargol, treu banya",
            "la-lluna-la-pruna": "La lluna, la pruna",
            "el-lleo-no-em-fa-por": "El lleó no em fa por",
        ] {
            XCTAssertEqual(SeedData.localizedTitle(seedID: seedID, locale: Locale(identifier: "tr")),
                           title, "\(seedID) is a proper noun — Catalan in every locale")
        }
    }

    func testTwinkleGetsItsCanonicalTurkishNurseryTitle() {
        XCTAssertEqual(SeedData.localizedTitle(seedID: "twinkle-twinkle", locale: Locale(identifier: "tr")),
                       "Küçük Yıldız")
        // …and stays English elsewhere.
        XCTAssertEqual(SeedData.localizedTitle(seedID: "twinkle-twinkle", locale: Locale(identifier: "en")),
                       "Twinkle Twinkle Little Star")
    }

    func testEnglishSongsWithoutACanonicalTurkishVersionKeepEnglishTitles() {
        for seedID in ["old-macdonald", "wheels-on-the-bus", "itsy-bitsy-spider"] {
            let en = SeedData.localizedTitle(seedID: seedID, locale: Locale(identifier: "en"))
            let tr = SeedData.localizedTitle(seedID: seedID, locale: Locale(identifier: "tr"))
            XCTAssertEqual(en, tr, "\(seedID): no canonical TR nursery version — keep the English title")
        }
    }

    /// displayTitle: seed songs go through the localized-title table; user
    /// songs show exactly what the user typed.
    func testDisplayTitleFallsBackForUserSongs() {
        let userSong = Song(title: "Deniz's Tune", bpm: 90)
        XCTAssertEqual(userSong.displayTitle, "Deniz's Tune")
    }
}
