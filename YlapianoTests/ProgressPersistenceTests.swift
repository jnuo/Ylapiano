import XCTest
import SwiftData
@testable import Ylapiano

/// B3 (#13) — per-song progress (bestStars + bestRung) persists on the Song
/// row. Store-is-state: SeedData never touches these fields, so a best
/// survives content refreshes and app relaunches alike. Only upgrades write —
/// a 2-star run never erases a 3-star best — and rung is meaningful only on
/// mastery-ladder songs.
@MainActor
final class ProgressPersistenceTests: XCTestCase {

    // MARK: - Stars: upgrades persist, downgrades don't

    func testNewBestStarsPersistsOnFinish() throws {
        let context = try freshContext()
        SeedData.seedIfNeeded(context: context)
        let twinkle = try song(seedID: "twinkle-twinkle", in: context)

        PlayerViewModel(song: twinkle).setResult(stars: 2)

        let reloaded = try song(seedID: "twinkle-twinkle", in: context)
        XCTAssertEqual(reloaded.bestStars, 2, "first finish must persist its stars")

        PlayerViewModel(song: twinkle).setResult(stars: 3)
        XCTAssertEqual(reloaded.bestStars, 3, "a better run must upgrade the best")
    }

    func testLowerResultNeverOverwritesBest() throws {
        let context = try freshContext()
        SeedData.seedIfNeeded(context: context)
        let twinkle = try song(seedID: "twinkle-twinkle", in: context)
        twinkle.bestStars = 3
        try context.save()

        PlayerViewModel(song: twinkle).setResult(stars: 1)

        XCTAssertEqual(twinkle.bestStars, 3, "a worse run never overwrites the best")
    }

    func testUserCreatedSongPersistsBestToo() throws {
        let context = try freshContext()
        let userSong = Song(title: "Riff for Pim", bpm: 100, notes: [
            NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
        ])
        context.insert(userSong)
        try context.save()

        PlayerViewModel(song: userSong).setResult(stars: 2)

        XCTAssertEqual(userSong.bestStars, 2, "user songs are rows like any other")
    }

    // MARK: - Rung: ladder-only, written at the climb

    func testClimbPersistsBestRung() throws {
        let context = try freshContext()
        SeedData.seedIfNeeded(context: context)
        let salta = try song(seedID: "plim-plim", in: context)

        let vm = PlayerViewModel(song: salta)
        vm.setResult(stars: 3)   // clean run → climb offered
        vm.climbRung()

        XCTAssertEqual(salta.bestRung, 1, "the climb must persist the new rung")
    }

    func testRungIsGatedToLadderSongs() throws {
        let context = try freshContext()
        SeedData.seedIfNeeded(context: context)
        let nonLadder = try song(seedID: "twinkle-twinkle", in: context)

        let vm = PlayerViewModel(song: nonLadder)
        vm.setResult(stars: 3)
        vm.climbRung()   // guard: no ladder → no-op

        XCTAssertEqual(nonLadder.bestRung, 0, "rung is meaningless off the ladder")
    }

    // MARK: - Restore on open

    func testLadderSongReopensAtBestRung() throws {
        let salta = SeedData.createSeedSongs().first { $0.seedID == "plim-plim" }!
        salta.bestRung = 2

        let vm = PlayerViewModel(song: salta)

        XCTAssertEqual(vm.metronome.bpm, MasteryLadder.rungs[2].bpm,
                       "song must open at the earned rung, not rung 1")
        XCTAssertEqual(vm.resultRungName, MasteryLadder.rungs[2].name)
    }

    func testStoredRungBeyondLadderClampsToTopRung() throws {
        let salta = SeedData.createSeedSongs().first { $0.seedID == "plim-plim" }!
        salta.bestRung = 99   // corrupt / future data must not crash or overshoot

        let vm = PlayerViewModel(song: salta)

        XCTAssertEqual(vm.metronome.bpm, MasteryLadder.rungs.last!.bpm)
        XCTAssertTrue(vm.isTopRung)
    }

    func testNonLadderSongIgnoresStoredRung() throws {
        let twinkle = SeedData.createSeedSongs().first { $0.seedID == "twinkle-twinkle" }!
        twinkle.bestRung = 3   // stray value must not drag a gentle song to 120 BPM

        let vm = PlayerViewModel(song: twinkle)

        XCTAssertEqual(vm.metronome.bpm, twinkle.bpm, "non-ladder songs keep their own BPM")
    }

    // MARK: - Simulated relaunch (new ModelContainer over the same store)

    func testBestSurvivesSimulatedRelaunch() throws {
        let storeDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("b3-relaunch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDir) }
        let storeURL = storeDir.appendingPathComponent("Ylapiano.store")

        // Launch 1: earn a best, then let the container deallocate.
        do {
            let container = try ModelContainer(
                for: Song.self, configurations: ModelConfiguration(url: storeURL))
            let context = ModelContext(container)
            SeedData.seedIfNeeded(context: context)
            let salta = try song(seedID: "plim-plim", in: context)

            let vm = PlayerViewModel(song: salta)
            vm.setResult(stars: 3)
            vm.climbRung()
        }

        // Launch 2: a fresh container over the same store — the app relaunch.
        let container = try ModelContainer(
            for: Song.self, configurations: ModelConfiguration(url: storeURL))
        let context = ModelContext(container)
        SeedData.seedIfNeeded(context: context)   // the real launch path runs seeding too

        let reloaded = try song(seedID: "plim-plim", in: context)
        XCTAssertEqual(reloaded.bestStars, 3, "best stars lost across relaunch")
        XCTAssertEqual(reloaded.bestRung, 1, "best rung lost across relaunch")
    }

    // MARK: - Helpers

    private func song(seedID: String, in context: ModelContext) throws -> Song {
        let songs = try context.fetch(FetchDescriptor<Song>())
        let matches = songs.filter { $0.seedID == seedID }
        XCTAssertEqual(matches.count, 1, "expected exactly one row for \(seedID)")
        return try XCTUnwrap(matches.first)
    }

    private func freshContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Song.self, configurations: config)
        return ModelContext(container)
    }
}
