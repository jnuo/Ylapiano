import XCTest
import AVFoundation
@testable import Ylapiano

/// B25 (#36) — standing ear-check tool.
///
/// Offline-renders every seed song's `notesData` through `PianoSampler`'s
/// own tone renderer (`renderTone`) into one `.m4a` per song, so the 13
/// transcriptions can be ear-checked at the desk instead of at the piano.
///
/// One command renders the full set (see `scripts/render-ear-check.sh`):
///
///     xcodebuild test -project Ylapiano.xcodeproj -scheme Ylapiano \
///       -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
///       -only-testing:YlapianoTests/EarCheckRenderTests
///
/// Output lands in `~/Downloads/ylapiano-ear-check/` (override with the
/// `EAR_CHECK_OUT` env var, `TEST_RUNNER_EAR_CHECK_OUT=` via xcodebuild) —
/// files named `01-plim-plim.m4a` … `13-itsy-bitsy-spider.m4a` in catalog
/// sortOrder, plus a `README.txt` with per-song ear-check notes.
///
/// Faithfulness: onsets are spaced by `duration.beats * 60 / bpm` — exactly
/// the spacing the falling-notes engine uses — and rests advance time
/// silently. Each struck tone rings its full natural decay (~1.5 s), same
/// as live play where buffers self-decay. The tone itself is the current
/// 4-harmonic synth placeholder (#34 swaps in Salamander later) — fine for
/// checking pitches and rhythm, which is what the ear-check is for.
@MainActor
final class EarCheckRenderTests: XCTestCase {

    private static let sampleRate = 48_000.0
    private static let velocity: UInt8 = 100

    // MARK: Output location

    /// `~/Downloads/ylapiano-ear-check` on the Mac running the tests.
    /// Simulator tests execute natively on the host, so writing outside the
    /// app container works; the host home is derived from `#filePath`
    /// because `NSHomeDirectory()` points into the simulator container.
    private static var outputDir: URL {
        if let override = ProcessInfo.processInfo.environment["EAR_CHECK_OUT"],
           !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let comps = URL(fileURLWithPath: #filePath).pathComponents
        if comps.count > 2, comps[1] == "Users" {
            return URL(fileURLWithPath: "/Users/\(comps[2])/Downloads/ylapiano-ear-check",
                       isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Downloads/ylapiano-ear-check", isDirectory: true)
    }

    // MARK: The render

    func testRenderAllSeedSongsForEarCheck() throws {
        let songs = SeedData.createSeedSongs()   // already in catalog sortOrder
        XCTAssertEqual(songs.count, 13, "ear-check set must cover the locked 13")

        let dir = Self.outputDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var readmeRows: [String] = []

        for song in songs {
            let seedID = try XCTUnwrap(song.seedID, "\(song.title) has no seedID")
            let fileName = String(format: "%02d-%@.m4a", song.sortOrder + 1, seedID)
            let url = dir.appendingPathComponent(fileName)

            let buffer = try Self.renderSong(song)

            // Non-silent gate: a transcription that renders to silence is a
            // harness bug, not something to discover with headphones on.
            let peak = Self.peak(of: buffer)
            XCTAssertGreaterThan(peak, 0.05, "\(fileName) rendered (near-)silent — peak \(peak)")

            try? FileManager.default.removeItem(at: url)
            // Scoped: AVAudioFile finalizes the container on dealloc — it must
            // be released before the read-back below or the .m4a is truncated.
            try {
                let file = try AVAudioFile(
                    forWriting: url,
                    settings: [
                        AVFormatIDKey: kAudioFormatMPEG4AAC,
                        AVSampleRateKey: Self.sampleRate,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderBitRateKey: 128_000,
                    ],
                    commonFormat: .pcmFormatFloat32,
                    interleaved: false
                )
                try file.write(from: buffer)
            }()

            // Duration gate: written file ≈ notesData beats at the song's bpm
            // (+ the 1.5 s natural ring-out after the last onset). AAC
            // priming/padding costs a few ms — 0.3 s tolerance is plenty to
            // catch a wrong-tempo or dropped-note render.
            let expected = Double(buffer.frameLength) / Self.sampleRate
            let readBack = try AVAudioFile(forReading: url)
            let actual = Double(readBack.length) / readBack.processingFormat.sampleRate
            XCTAssertEqual(actual, expected, accuracy: 0.3,
                           "\(fileName) duration \(actual)s ≠ expected \(expected)s")

            let beats = song.notes.reduce(0.0) { $0 + $1.duration.beats }
            let musicalSeconds = beats * 60.0 / Double(song.bpm)
            print(String(format: "EARCHECK | %@ | bpm=%d | beats=%.2f | musical=%.1fs | file=%.1fs",
                         fileName, song.bpm, beats, musicalSeconds, actual))

            readmeRows.append(Self.readmeRow(
                fileName: fileName, song: song, seedID: seedID, seconds: musicalSeconds))
        }

        let readmeURL = dir.appendingPathComponent("README.txt")
        try Self.readme(rows: readmeRows).write(to: readmeURL, atomically: true, encoding: .utf8)
        print("EARCHECK | wrote \(songs.count) files + README.txt → \(dir.path)")
    }

    // MARK: Offline mixdown

    /// Mix a whole song into one PCM buffer: each sounding note's tone buffer
    /// (from `PianoSampler.renderTone`, the app's live sound path) is added at
    /// its beat-grid onset; rests advance the clock and mix nothing.
    private static func renderSong(_ song: Song) throws -> AVAudioPCMBuffer {
        let notes = song.notes
        let secondsPerBeat = 60.0 / Double(song.bpm)
        let totalBeats = notes.reduce(0.0) { $0 + $1.duration.beats }

        // Cache one tone per distinct pitch — same buffers the app caches.
        var tones: [UInt8: AVAudioPCMBuffer] = [:]
        for note in notes where !note.isRest {
            let pitch = Pitch(solfege: note.solfege, octave: note.octave)
            if tones[pitch.midi] == nil {
                tones[pitch.midi] = PianoSampler.renderTone(pitch: pitch, velocity: velocity)
            }
        }
        let tailFrames = Int(tones.values.map { Int($0.frameLength) }.max() ?? Int(1.5 * sampleRate))

        let songFrames = Int((totalBeats * secondsPerBeat * sampleRate).rounded(.up))
        let totalFrames = songFrames + tailFrames
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let mix = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalFrames))!
        mix.frameLength = AVAudioFrameCount(totalFrames)
        let out = mix.floatChannelData![0]
        // frameCapacity-fresh buffers aren't guaranteed zeroed.
        out.update(repeating: 0, count: totalFrames)

        var beatCursor = 0.0
        for note in notes {
            defer { beatCursor += note.duration.beats }
            guard !note.isRest else { continue }
            let pitch = Pitch(solfege: note.solfege, octave: note.octave)
            guard let tone = tones[pitch.midi] else { continue }
            let onset = Int((beatCursor * secondsPerBeat * sampleRate).rounded())
            let src = tone.floatChannelData![0]
            let count = min(Int(tone.frameLength), totalFrames - onset)
            for i in 0..<max(count, 0) {
                out[onset + i] += src[i]
            }
        }

        // Overlapping decay tails can sum past full scale — normalize down
        // (never up) so the .m4a can't clip.
        let peak = Self.peak(of: mix)
        if peak > 0.95 {
            let scale = Float(0.95 / peak)
            for i in 0..<totalFrames { out[i] *= scale }
        }
        return mix
    }

    private static func peak(of buffer: AVAudioPCMBuffer) -> Float {
        let data = buffer.floatChannelData![0]
        var peak: Float = 0
        for i in 0..<Int(buffer.frameLength) {
            peak = max(peak, abs(data[i]))
        }
        return peak
    }

    // MARK: README

    /// One ear-check line per song — condensed from the B2 (#12) ear-check
    /// sheet. Keyed by seedID; update alongside any transcription change.
    private static let earCheckNotes: [String: String] = [
        "plim-plim": "The held Sol half-notes after \"Do Mi-Fa\" — does the reference hold Sol or Mi? The named Salta trap; your call resolves it.",
        "sol-solet": "Straightforward — original's eighth-note triplets on \"vi-ne'm-a\" simplified to eighth pairs.",
        "cargol-treu-banya": "Final line Re-Do-Re-Fa-Do: source scan ambiguous (\"ja al\" could be Re, \"ta-\" could be Mi). Also confirm the quarter REST after \"vi\" is audible.",
        "la-lluna-la-pruna": "Modal tune mapped to E-Phrygian on white keys — ending on Mi is the tune, not an error. Check the final Mi and the dotted Fa.",
        "el-lleo-no-em-fa-por": "Low-res scan source — the Re's in the closing \"Do Mi Re Do Re Mi Do\" could be off by a step.",
        "kirmizi-balik": "Pitches solid (4 sources agree, Do-Re-Mi only); the RHYTHM is entirely set by feel — that's what to check.",
        "ali-babanin-ciftligi": "Real Turkish tune (NOT Old MacDonald), locally credited to Erdoğan Çaplı — PD status questionable. Default on 07-11: swap to a PD-safe TR song.",
        "mini-mini-bir-kus": "Middle section single-sourced; rhythm set by feel — verify the \"cik cik cik cik\" section.",
        "portakali-soydum": "NO canonical melody exists (tekerleme) — coded as the classic playground sol-mi chant. Default on 07-11: keep the coded chant.",
        "old-macdonald": "Unchanged standard verse — quick sanity pass.",
        "twinkle-twinkle": "Unchanged standard first verse — quick sanity pass.",
        "wheels-on-the-bus": "Middle \"round and round\" bars use the Wikipedia variant (Re Re Re / Si3 La3 Sol3) — a second folk variant exists; confirm it's the one you sing.",
        "itsy-bitsy-spider": "\"And the\" pickup coded as Si3-Si3 — a documented Sol3-Sol3 variant exists, pick whichever you sing. 6/8 lilt kept via dotted notes.",
    ]

    /// Songs gated on an open decision issue.
    private static let pendingDecisions: [String: String] = [
        "ali-babanin-ciftligi": "#42 (D1)",
        "portakali-soydum": "#43 (D2)",
    ]

    private static func readmeRow(fileName: String, song: Song, seedID: String, seconds: Double) -> String {
        var row = "\(fileName) — \(song.title) · \(song.bpm) BPM · ~\(Int(seconds.rounded()))s"
        if let decision = pendingDecisions[seedID] {
            row += "\n   ⚠️ DECISION PENDING \(decision)"
        }
        if let note = earCheckNotes[seedID] {
            row += "\n   ear-check: \(note)"
        }
        return row
    }

    private static func readme(rows: [String]) -> String {
        """
        YLaPiano ear-check renders — B25 (#36)
        ======================================

        One .m4a per seed song, rendered offline through the app's own sound
        path (PianoSampler's tone renderer). Note onsets follow each song's
        notesData exactly — duration.beats at the song's BPM, rests honored —
        so what you hear is the timing the app plays.

        Sound: the current sampler is a 4-harmonic SYNTH PLACEHOLDER (#34
        swaps in the Salamander piano later). That's fine for this ear-check —
        you're verifying PITCHES and RHYTHM, not tone quality. Each struck
        note rings its natural ~1.5 s decay regardless of note value, same as
        the app live.

        Re-render after any transcription edit: scripts/render-ear-check.sh
        (or the xcodebuild -only-testing:YlapianoTests/EarCheckRenderTests
        command in EarCheckRenderTests.swift).

        The 26-box ear-check sheet lives in issue #12. Two songs are gated on
        decisions due 2026-07-11 — #42 (Ali Baba PD status) and #43 (Portakalı
        Soydum melody). Fallback: 11-song catalog if both stay contested.

        Songs (catalog order)
        ---------------------
        \(rows.joined(separator: "\n\n"))
        """
    }
}
