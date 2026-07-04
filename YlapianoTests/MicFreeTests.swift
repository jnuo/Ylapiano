import XCTest

/// B5 (#27) — the mic pipeline is DELETED, not deactivated. These greppable
/// guards keep it deleted: any reintroduction of pitch detection, a record
/// audio-session category, the mic permission key, or mic UI copy fails the
/// suite. They back the "no mic, no data" store claim (B19 #29).
///
/// Scans the app source tree + project file on the host (simulator tests run
/// natively, so `#filePath` reaches the repo — same pattern as
/// `EarCheckRenderTests`).
final class MicFreeTests: XCTestCase {

    /// Repo root, derived from this file's path (`YlapianoTests/MicFreeTests.swift`).
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // MicFreeTests.swift
        .deletingLastPathComponent()   // YlapianoTests/

    private static let appSourceDir = repoRoot.appendingPathComponent("Ylapiano")
    private static let pbxproj = repoRoot.appendingPathComponent("Ylapiano.xcodeproj/project.pbxproj")

    /// Every file in the app target's source tree (code + resources).
    private static func appFiles() throws -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: appSourceDir, includingPropertiesForKeys: [.isRegularFileKey]) else {
            XCTFail("Cannot enumerate \(appSourceDir.path)")
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { url in
            (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
    }

    /// Assert `text` contains none of `tokens` (case-insensitive), reporting
    /// which file and token matched.
    private func assertFree(of tokens: [String], in text: String, file fileDescription: String) {
        for token in tokens where text.range(of: token, options: .caseInsensitive) != nil {
            XCTFail("\(fileDescription) still references the deleted mic pipeline: '\(token)'")
        }
    }

    /// No pitch detection, no record-category audio session, no mic permission
    /// request anywhere in the app source (Swift, strings, everything).
    func testAppSourcesHaveNoMicPipeline() throws {
        let tokens = [
            "PitchDetector",
            "playAndRecord",             // AVAudioSession record categories…
            "setCategory(.record",       // …in both spellings
            "requestRecordPermission",
            "NSMicrophoneUsageDescription",
            "microphone",                // user-facing copy, EN
            "micrófono",                 // user-facing copy, ES
        ]
        for url in try Self.appFiles() {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            assertFree(of: tokens, in: text, file: url.lastPathComponent)
        }
    }

    /// The project file carries no mic permission key (both build configs) and
    /// no reference to the deleted PitchDetector.swift.
    func testProjectFileHasNoMicEntries() throws {
        let text = try String(contentsOf: Self.pbxproj, encoding: .utf8)
        assertFree(
            of: ["NSMicrophoneUsageDescription", "PitchDetector"],
            in: text,
            file: "project.pbxproj"
        )
    }
}
