import XCTest
@testable import Ylapiano

final class CatalogTests: XCTestCase {

    // MARK: - Sub-task 1: dotted durations + rests, backward-compatible JSON

    // A build-6 notesData blob (no isRest key, four legacy durations) must
    // decode without loss — this is the upgrade path for every existing store.
    func testDecodesBuild6NotesDataBlobWithoutLoss() throws {
        let build6JSON = """
        [
            {"id":"11111111-1111-1111-1111-111111111111","solfege":"Do","octave":4,"duration":"quarter"},
            {"id":"22222222-2222-2222-2222-222222222222","solfege":"Mi","octave":4,"duration":"eighth"},
            {"id":"33333333-3333-3333-3333-333333333333","solfege":"Sol","octave":3,"duration":"half"},
            {"id":"44444444-4444-4444-4444-444444444444","solfege":"Do","octave":5,"duration":"whole"}
        ]
        """.data(using: .utf8)!

        let notes = try JSONDecoder().decode([NoteEntry].self, from: build6JSON)

        XCTAssertEqual(notes.count, 4, "build-6 blob lost entries on decode")
        XCTAssertEqual(notes[0].solfege, .Do)
        XCTAssertEqual(notes[0].octave, 4)
        XCTAssertEqual(notes[0].duration, .quarter)
        XCTAssertEqual(notes[1].duration, .eighth)
        XCTAssertEqual(notes[2].solfege, .Sol)
        XCTAssertEqual(notes[2].octave, 3)
        XCTAssertEqual(notes[2].duration, .half)
        XCTAssertEqual(notes[3].duration, .whole)
        XCTAssertTrue(notes.allSatisfy { !$0.isRest }, "legacy notes must decode as sounding notes")
        XCTAssertEqual(notes[0].id.uuidString, "11111111-1111-1111-1111-111111111111",
                       "entry UUIDs must survive decode")
    }

    // Dotted notes and rests survive an encode→decode round-trip.
    func testDottedAndRestRoundTrip() throws {
        let original = [
            NoteEntry(solfege: .Do, octave: 4, duration: .dottedQuarter),
            NoteEntry(solfege: .Mi, octave: 4, duration: .dottedHalf),
            NoteEntry(solfege: .Sol, octave: 4, duration: .dottedEighth),
            NoteEntry(solfege: .Do, octave: 4, duration: .quarter, isRest: true),
            NoteEntry(solfege: .Do, octave: 4, duration: .eighth, isRest: true),
        ]

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode([NoteEntry].self, from: data)

        XCTAssertEqual(decoded.count, original.count)
        for (a, b) in zip(original, decoded) {
            XCTAssertEqual(a.solfege, b.solfege)
            XCTAssertEqual(a.octave, b.octave)
            XCTAssertEqual(a.duration, b.duration)
            XCTAssertEqual(a.isRest, b.isRest, "rest flag lost in round-trip")
        }
    }

    // Dotted beat math: the falling-notes engine spaces blocks off `beats`.
    func testDottedDurationBeats() {
        XCTAssertEqual(NoteDuration.dottedHalf.beats, 3.0)
        XCTAssertEqual(NoteDuration.dottedQuarter.beats, 1.5)
        XCTAssertEqual(NoteDuration.dottedEighth.beats, 0.75)
    }
}

// MARK: - Sub-task 2: the locked 13-song catalog

extension CatalogTests {

    // product/decisions/2026-06-10-song-list.md — exactly these, no extras.
    static let lockedCatalog: [(seedID: String, language: String)] = [
        // Catalan (5)
        ("plim-plim", "ca"),
        ("sol-solet", "ca"),
        ("cargol-treu-banya", "ca"),
        ("la-lluna-la-pruna", "ca"),
        ("el-lleo-no-em-fa-por", "ca"),
        // Turkish (4)
        ("kirmizi-balik", "tr"),
        ("ali-babanin-ciftligi", "tr"),
        ("mini-mini-bir-kus", "tr"),
        ("portakali-soydum", "tr"),
        // English (4)
        ("old-macdonald", "en"),
        ("twinkle-twinkle", "en"),
        ("wheels-on-the-bus", "en"),
        ("itsy-bitsy-spider", "en"),
    ]

    func testCatalogIsExactlyTheLocked13() {
        let seeds = SeedData.createSeedSongs()
        XCTAssertEqual(seeds.count, 13, "catalog must be exactly the locked 13")

        let byID = Dictionary(uniqueKeysWithValues: seeds.compactMap { s in s.seedID.map { ($0, s) } })
        XCTAssertEqual(byID.count, 13, "every seed needs a unique seedID")

        for expected in Self.lockedCatalog {
            guard let song = byID[expected.seedID] else {
                XCTFail("missing seed \(expected.seedID)")
                continue
            }
            XCTAssertEqual(song.language, expected.language,
                           "\(expected.seedID) has wrong language")
        }
    }

    // Every sounding note must land on a real lane of the shipped keyboard —
    // laneIndex(for:) is the exact gate the game uses (notes without a lane
    // are silently dropped by FallingNotesScene).
    func testEverySeedFitsThePlayableEnvelope() {
        let layout = KeyboardLayout.default
        for song in SeedData.createSeedSongs() {
            XCTAssertFalse(song.notes.isEmpty, "\(song.title) has no notes")
            for note in song.notes where !note.isRest {
                let pitch = Pitch(solfege: note.solfege, octave: note.octave)
                XCTAssertNotNil(layout.laneIndex(for: pitch),
                                "\(song.title): \(note.solfege.rawValue)\(note.octave) has no lane on the shipped keyboard")
            }
        }
    }
}

// MARK: - Sub-task 3: difficultyRank easy→hard within each language

extension CatalogTests {

    func testDifficultyRanksStrictlyOrderedPerLanguage() {
        let seeds = SeedData.createSeedSongs()
        let byLanguage = Dictionary(grouping: seeds, by: { $0.language ?? "?" })

        for (language, songs) in byLanguage {
            let ranks = songs.map(\.difficultyRank).sorted()
            XCTAssertEqual(ranks, Array(1...songs.count),
                           "\(language) ranks must be exactly 1...\(songs.count), got \(ranks)")
        }
    }
}
