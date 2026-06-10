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
