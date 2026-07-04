import XCTest
@testable import Ylapiano

/// B9 (#28) — art-system guards.
///
/// 1. Icon completeness: every seed song in the catalog has a hand-drawn
///    picture icon — a new song added without art fails here, not on a
///    kid's home screen.
/// 2. Palette lock: `Theme.swift` is the ONLY place a literal color may be
///    defined, and it holds at most 12 tokens. Greppable file-system guard,
///    same pattern as `MicFreeTests`.
final class ArtSystemTests: XCTestCase {

    /// Repo root, derived from this file's path (`YlapianoTests/ArtSystemTests.swift`).
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // ArtSystemTests.swift
        .deletingLastPathComponent()   // YlapianoTests/

    private static let appSourceDir = repoRoot.appendingPathComponent("Ylapiano")

    private static func appSwiftFiles() throws -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: appSourceDir, includingPropertiesForKeys: [.isRegularFileKey]) else {
            XCTFail("Cannot enumerate \(appSourceDir.path)")
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    }

    // MARK: - Icon completeness

    func testEveryCatalogSongHasAPictureIcon() throws {
        let seeds = SeedData.createSeedSongs()
        XCTAssertEqual(seeds.count, 13, "the locked catalog is 13 songs")
        for song in seeds {
            let seedID = try XCTUnwrap(song.seedID, "\(song.title) has no seedID")
            XCTAssertTrue(
                SongIconArt.hasIcon(for: seedID),
                "no picture icon for '\(seedID)' (\(song.title)) — add it to SongIconArt.drawers"
            )
        }
    }

    // MARK: - Palette lock

    /// Literal RGB color constructors (`Color(red:…)`, `UIColor(red:…)`,
    /// `SKColor(red:…)`, hue variants) may exist only in Theme.swift.
    /// Everything else must consume `Palette` tokens. Grayscale shading
    /// (`Color(white:)` on the piano keys) is deliberately allowed — greys
    /// are shading, not palette colors.
    func testNoHardcodedColorsOutsideTheme() throws {
        let literalMarkers = ["Color(red", "Color(hue", "Color(#colorLiteral"]
        for url in try Self.appSwiftFiles() where url.lastPathComponent != "Theme.swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for marker in literalMarkers where text.contains(marker) {
                XCTFail("\(url.lastPathComponent) defines a literal color ('\(marker)…') — use a Palette token from Theme.swift")
            }
        }
    }

    /// The palette is LOCKED at ≤12 tokens (committee decision, #28). Counts
    /// literal color definitions inside Theme.swift.
    func testPaletteHasAtMostTwelveTokens() throws {
        let theme = Self.appSourceDir.appendingPathComponent("Theme.swift")
        let text = try String(contentsOf: theme, encoding: .utf8)
        let tokenCount = text.components(separatedBy: "= Color(red").count - 1
        XCTAssertGreaterThan(tokenCount, 0, "Theme.swift should define the palette")
        XCTAssertLessThanOrEqual(tokenCount, 12, "palette is locked at 12 tokens — remove one before adding another")
    }
}
