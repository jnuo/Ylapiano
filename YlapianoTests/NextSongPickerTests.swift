import XCTest
import SwiftData
@testable import Ylapiano

/// B26 (#37) — the result screen's next-song selection rule, exhaustively:
///  1. first never-played catalog song (bestStars == 0), catalog order;
///  2. all played → least-starred (ties → catalog order);
///  3. all 3-starred → loops back to the first catalog song (never nothing);
/// the just-finished song is always excluded (replay covers "again"), and
/// user-created songs are NEVER suggested — catalog (seed) songs only.
@MainActor
final class NextSongPickerTests: XCTestCase {

    // MARK: - Rule 1: first never-played, catalog order

    func testPicksFirstNeverPlayedInCatalogOrder() {
        let songs = catalog(stars: [2, 3, 0, 0, 1])
        let next = NextSongPicker.next(after: songs[0], in: songs)
        XCTAssertEqual(next?.seedID, "seed-2", "first bestStars == 0 in catalog order wins")
    }

    func testNeverPlayedBeatsALowerStarredPlayedSong() {
        // seed-1 has 1 star (lowest played) but seed-3 was never played at all.
        let songs = catalog(stars: [3, 1, 3, 0])
        let next = NextSongPicker.next(after: songs[0], in: songs)
        XCTAssertEqual(next?.seedID, "seed-3", "never-played outranks least-starred")
    }

    func testCatalogOrderMeansSortOrderNotArrayOrder() {
        // Shuffled input array must not change the pick — order is sortOrder.
        let songs = catalog(stars: [1, 0, 0, 2])
        let shuffled = [songs[3], songs[1], songs[0], songs[2]]
        let next = NextSongPicker.next(after: songs[0], in: shuffled)
        XCTAssertEqual(next?.seedID, "seed-1", "selection must sort by sortOrder, not input order")
    }

    // MARK: - The just-finished song is excluded

    func testCurrentSongIsExcludedEvenWhenNeverPlayed() {
        // Everything unplayed and the kid just finished the catalog's first
        // song (its bestStars write may not have landed yet) — suggest the
        // SECOND song, never "the one you just played".
        let songs = catalog(stars: [0, 0, 0])
        let next = NextSongPicker.next(after: songs[0], in: songs)
        XCTAssertEqual(next?.seedID, "seed-1")
    }

    func testCurrentSongIsExcludedFromLeastStarred() {
        // Current is the sole least-starred song → the next-lowest wins.
        let songs = catalog(stars: [1, 3, 2, 3])
        let next = NextSongPicker.next(after: songs[0], in: songs)
        XCTAssertEqual(next?.seedID, "seed-2", "current can't be its own suggestion")
    }

    // MARK: - Rule 2: all played → least-starred, catalog-order ties

    func testAllPlayedPicksLeastStarred() {
        let songs = catalog(stars: [3, 2, 1, 2])
        let next = NextSongPicker.next(after: songs[0], in: songs)
        XCTAssertEqual(next?.seedID, "seed-2", "lowest bestStars wins once all are played")
    }

    func testLeastStarredTieBreaksByCatalogOrder() {
        let songs = catalog(stars: [3, 2, 1, 1, 1])
        let next = NextSongPicker.next(after: songs[0], in: songs)
        XCTAssertEqual(next?.seedID, "seed-2", "ties resolve to the earliest catalog slot")
    }

    // MARK: - Rule 3: everything 3-starred → loop to the first song

    func testAllThreeStarredLoopsBackToFirstCatalogSong() {
        let songs = catalog(stars: [3, 3, 3, 3])
        let next = NextSongPicker.next(after: songs[2], in: songs)
        XCTAssertEqual(next?.seedID, "seed-0", "a fully-mastered catalog restarts from the top")
    }

    func testAllThreeStarredFromTheFirstSongOffersTheSecond() {
        let songs = catalog(stars: [3, 3, 3])
        let next = NextSongPicker.next(after: songs[0], in: songs)
        XCTAssertEqual(next?.seedID, "seed-1", "current stays excluded even in the loop-back case")
    }

    // MARK: - User songs are never suggested

    func testUserSongsAreExcludedFromSuggestions() throws {
        // Mixed store: the real seeded catalog + two user songs, one of them
        // never played (the most tempting candidate under rule 1).
        let context = try freshContext()
        SeedData.seedIfNeeded(context: context)
        let userSong = Song(title: "Riff for Pim", bpm: 100, sortOrder: -1)
        let playedUserSong = Song(title: "Dad's Song", bpm: 90, sortOrder: 99)
        playedUserSong.bestStars = 1
        context.insert(userSong)
        context.insert(playedUserSong)
        try context.save()

        let all = try context.fetch(FetchDescriptor<Song>())
        for song in all where song.isSeed { song.bestStars = 3 }   // catalog mastered

        let current = all.first { $0.seedID == "twinkle-twinkle" }!
        let next = try XCTUnwrap(NextSongPicker.next(after: current, in: all))
        XCTAssertTrue(next.isSeed, "user-created songs must never be suggested")
        XCTAssertEqual(next.sortOrder, all.filter(\.isSeed).map(\.sortOrder).min(),
                       "mastered catalog loops back to its first song, skipping user rows")
    }

    func testFinishingAUserSongStillSuggestsFromTheCatalog() {
        var songs = catalog(stars: [3, 0, 2])
        let userSong = Song(title: "My Song", bpm: 90, sortOrder: 50)
        songs.append(userSong)
        let next = NextSongPicker.next(after: userSong, in: songs)
        XCTAssertEqual(next?.seedID, "seed-1", "the bridge works from user songs too")
    }

    // MARK: - Never show nothing (except a truly empty catalog)

    func testAlwaysReturnsSomethingWhenAnotherCatalogSongExists() {
        for stars in [[0, 0], [3, 3], [1, 2], [0, 3]] {
            let songs = catalog(stars: stars)
            XCTAssertNotNil(NextSongPicker.next(after: songs[0], in: songs),
                            "stars \(stars): a second catalog song must always be offered")
        }
    }

    func testNilOnlyWhenNoOtherCatalogSongExists() {
        let only = catalog(stars: [2])
        XCTAssertNil(NextSongPicker.next(after: only[0], in: only),
                     "no OTHER catalog song → no card (replay still covers it)")
        XCTAssertNil(NextSongPicker.next(after: nil, in: []),
                     "empty store → no card, no crash")
    }

    // MARK: - Helpers

    /// A minimal catalog: seed songs seed-0…seed-N in catalog (sortOrder)
    /// order with the given bestStars.
    private func catalog(stars: [Int]) -> [Song] {
        stars.enumerated().map { index, best in
            let song = Song(title: "Seed \(index)", bpm: 90,
                            seedID: "seed-\(index)", sortOrder: index)
            song.bestStars = best
            return song
        }
    }

    private func freshContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Song.self, configurations: config)
        return ModelContext(container)
    }
}
