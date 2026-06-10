import XCTest
import SwiftData
@testable import Ylapiano

final class SongIdentityTests: XCTestCase {

    // Sub-task 1: every seed song carries a stable, non-nil seedID.
    func testEverySeedHasANonNilSeedID() {
        let seeds = SeedData.createSeedSongs()
        XCTAssertFalse(seeds.isEmpty, "expected at least one seed song")
        for seed in seeds {
            XCTAssertNotNil(seed.seedID, "seed \"\(seed.title)\" has no seedID")
            XCTAssertFalse(seed.seedID?.isEmpty ?? true, "seed \"\(seed.title)\" has an empty seedID")
        }
    }

    // Sub-task 1: seedIDs are unique across the catalog.
    func testSeedIDsAreUnique() {
        let ids = SeedData.createSeedSongs().compactMap { $0.seedID }
        XCTAssertEqual(ids.count, Set(ids).count, "duplicate seedIDs in catalog")
    }

    // Sub-task 2: seeding twice inserts zero duplicates.
    func testSeedingTwiceInsertsNoDuplicates() throws {
        let context = try freshContext()
        SeedData.seedIfNeeded(context: context)
        let countAfterFirst = try context.fetch(FetchDescriptor<Song>()).count
        SeedData.seedIfNeeded(context: context)
        let countAfterSecond = try context.fetch(FetchDescriptor<Song>()).count
        XCTAssertEqual(countAfterFirst, countAfterSecond, "second seeding pass inserted duplicates")
    }

    // Sub-task 2: a seed is matched by seedID even if its display title changed
    // between builds (title-keyed matching would insert a duplicate).
    func testSeedMatchedBySeedIDWhenTitleDiffers() throws {
        let context = try freshContext()
        let renamed = Song(title: "Old Title From Previous Build", bpm: 60, seedID: "plim-plim")
        context.insert(renamed)
        try context.save()

        SeedData.seedIfNeeded(context: context)

        let songs = try context.fetch(FetchDescriptor<Song>())
        let plims = songs.filter { $0.seedID == "plim-plim" }
        XCTAssertEqual(plims.count, 1, "seedID match must not duplicate a renamed seed")
    }

    // Sub-task 2: a user-created song sharing a seed's title is left alone —
    // the seed is still inserted separately.
    func testUserSongWithSeedTitleIsNotAdopted() throws {
        let context = try freshContext()
        let userSong = Song(title: "Plim Plim (Salta l'Esquirol)", bpm: 99)
        context.insert(userSong)
        try context.save()

        SeedData.seedIfNeeded(context: context)

        let songs = try context.fetch(FetchDescriptor<Song>())
        XCTAssertEqual(songs.filter { $0.seedID == "plim-plim" }.count, 1, "seed missing")
        XCTAssertEqual(songs.filter { $0.seedID == nil }.count, 1, "user song was adopted or deleted")
        XCTAssertEqual(songs.first(where: { $0.seedID == nil })?.bpm, 99, "user song was overwritten")
    }

    private func freshContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Song.self, configurations: config)
        return ModelContext(container)
    }

    // Sub-task 1: a fresh store accepts the migrated Song schema (defaults in place).
    func testFreshStoreLaunchesWithNewSchema() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Song.self, configurations: config)
        let context = ModelContext(container)
        SeedData.seedIfNeeded(context: context)
        let songs = try context.fetch(FetchDescriptor<Song>())
        XCTAssertFalse(songs.isEmpty, "fresh store should contain seed songs")
    }
}
