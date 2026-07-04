import XCTest
import SwiftData
@testable import Ylapiano

/// B24 — bundle-is-truth, store-is-state (#35).
///
/// The bundle owns every intrinsic field of a seed song (title, notesData,
/// bpm, language, difficultyRank, sortOrder) and re-asserts them on every
/// launch. The store owns only user STATE: the row identity that carries it
/// (Song.id), the B3 progress fields (bestStars/bestRung), and user-created
/// songs (seedID == nil). Seeds that left the bundle — a stale seedID, or a
/// pre-seedID row matching a frozen build-6 shape — are retired.
final class SeedRefreshTests: XCTestCase {

    // MARK: - Content refresh (bundle-is-truth)

    // A seeded row with stale content (an older build's transcription) is
    // refreshed from the bundle on the next seeding pass.
    func testSeedContentRefreshesFromBundleOnRelaunch() throws {
        let context = try freshContext()
        SeedData.seedIfNeeded(context: context)

        let stale = try song(seedID: "twinkle-twinkle", in: context)
        stale.title = "Twinkle (old wording)"
        stale.bpm = 42
        stale.notes = [NoteEntry(solfege: .Do, octave: 4, duration: .whole)]
        stale.difficultyRank = 99
        stale.language = "xx"
        stale.sortOrder = 999
        try context.save()

        SeedData.seedIfNeeded(context: context)

        let bundle = try XCTUnwrap(
            SeedData.createSeedSongs().first { $0.seedID == "twinkle-twinkle" })
        let refreshed = try song(seedID: "twinkle-twinkle", in: context)
        XCTAssertEqual(refreshed.title, bundle.title, "title not re-asserted")
        XCTAssertEqual(refreshed.bpm, bundle.bpm, "bpm not re-asserted")
        XCTAssertTrue(refreshed.notes.musicallyEquals(bundle.notes), "notes not re-asserted")
        XCTAssertEqual(refreshed.difficultyRank, bundle.difficultyRank)
        XCTAssertEqual(refreshed.language, bundle.language)
        XCTAssertEqual(refreshed.sortOrder, bundle.sortOrder)
    }

    // Store-is-state: a content refresh mutates the existing row in place —
    // it never deletes + reinserts. Row identity (Song.id) is the anchor the
    // B3 progress fields (bestStars/bestRung) hang off; anything not in the
    // refreshed content list survives by construction.
    func testStateCarrierSurvivesContentRefresh() throws {
        let context = try freshContext()
        SeedData.seedIfNeeded(context: context)

        let seeded = try song(seedID: "plim-plim", in: context)
        let rowID = seeded.id
        let persistentID = seeded.persistentModelID
        seeded.bpm = 42 // stale content, forces a real refresh
        seeded.bestStars = 3 // B3 state fields — must survive the refresh
        seeded.bestRung = 2
        try context.save()

        SeedData.seedIfNeeded(context: context)

        let refreshed = try song(seedID: "plim-plim", in: context)
        XCTAssertEqual(refreshed.id, rowID, "refresh must not replace the row")
        XCTAssertEqual(refreshed.persistentModelID, persistentID,
                       "refresh must mutate in place, not delete + reinsert")
        XCTAssertEqual(refreshed.bestStars, 3, "bestStars is state — refresh must not touch it")
        XCTAssertEqual(refreshed.bestRung, 2, "bestRung is state — refresh must not touch it")
    }

    // A user song is never refreshed — even one that shares a seed's title
    // and bpm but carries the user's own notes.
    func testUserSongContentIsNeverTouched() throws {
        let context = try freshContext()
        SeedData.seedIfNeeded(context: context)

        let userNotes = [
            NoteEntry(solfege: .Si, octave: 3, duration: .eighth),
            NoteEntry(solfege: .Do, octave: 5, duration: .half),
        ]
        let userSong = Song(title: "Old MacDonald", bpm: 100, notes: userNotes)
        context.insert(userSong)
        try context.save()

        SeedData.seedIfNeeded(context: context)

        let songs = try context.fetch(FetchDescriptor<Song>())
        let user = try XCTUnwrap(songs.first { $0.id == userSong.id }, "user song was retired")
        XCTAssertNil(user.seedID, "user song wrongly adopted")
        XCTAssertTrue(user.notes.musicallyEquals(userNotes), "user notes were overwritten")
    }

    // MARK: - Legacy retirement (a): stale seedID

    // A stored seed whose seedID left the bundle catalog is retired.
    func testSeedWithIDAbsentFromCatalogIsRetired() throws {
        let context = try freshContext()
        let dropped = Song(title: "Hot Cross Buns", bpm: 80,
                           seedID: "hot-cross-buns", language: "en", difficultyRank: 1)
        context.insert(dropped)
        try context.save()

        SeedData.seedIfNeeded(context: context)

        let songs = try context.fetch(FetchDescriptor<Song>())
        XCTAssertFalse(songs.contains { $0.seedID == "hot-cross-buns" },
                       "seedID absent from the bundle must be retired")
        XCTAssertEqual(songs.count, SeedData.createSeedSongs().count)
    }

    // MARK: - Legacy retirement (b): pre-seedID build-6 shapes

    // A pre-seedID row matching a frozen build-6 seed shape is retired —
    // it was never a user composition.
    func testLegacyShapeWithoutSeedIDIsRetired() throws {
        let context = try freshContext()
        context.insert(Build6Store.frereJacques())
        try context.save()

        SeedData.seedIfNeeded(context: context)

        let songs = try context.fetch(FetchDescriptor<Song>())
        XCTAssertFalse(songs.contains { $0.title == "Frère Jacques" },
                       "dropped legacy seed must be retired")
        XCTAssertEqual(songs.count, SeedData.createSeedSongs().count)
    }

    // The retirement matcher is the B1 adoption matcher inverted: title, bpm
    // AND notes must all match a legacy shape. A near miss in any one of
    // them means user work — it survives.
    func testNearMissOfLegacyShapeSurvives() throws {
        let context = try freshContext()
        // Same title + bpm as legacy Hot Cross Buns, user's own notes.
        var editedNotes = Build6Store.hotCrossBuns().notes
        editedNotes.append(NoteEntry(solfege: .Do, octave: 5, duration: .whole))
        let editedSong = Song(title: "Hot Cross Buns", bpm: 80, notes: editedNotes)
        // Same title + notes as legacy Deniz's Lullaby, user's own tempo.
        let retimed = Build6Store.denizsLullaby()
        retimed.bpm = 112
        context.insert(editedSong)
        context.insert(retimed)
        try context.save()

        SeedData.seedIfNeeded(context: context)

        let songs = try context.fetch(FetchDescriptor<Song>())
        XCTAssertTrue(songs.contains { $0.id == editedSong.id },
                      "edited-notes song is user work — must survive")
        XCTAssertTrue(songs.contains { $0.id == retimed.id },
                      "re-tempoed song is user work — must survive")
    }

    // MARK: - Build-6 store upgrade (the zombie bug, end to end)

    // Simulated build-6 store: the full old 9-song catalog (seeded by title,
    // seedID didn't exist) plus one genuine user song. After the new seeding
    // pass: exactly the 13 current songs with fresh content, the 5 dropped
    // legacy songs gone, the user song untouched, and the 4 carried-over
    // songs adopted in place (row identity — the future progress carrier —
    // preserved).
    func testBuild6StoreUpgradeYieldsCurrentCatalogPlusUserSongs() throws {
        let context = try freshContext()
        let legacySongs = Build6Store.allSongs()
        for song in legacySongs { context.insert(song) }
        let userNotes = [
            NoteEntry(solfege: .Mi, octave: 3, duration: .quarter),
            NoteEntry(solfege: .Fa, octave: 3, duration: .quarter),
        ]
        let userSong = Song(title: "Riff for Pim", bpm: 123, notes: userNotes)
        context.insert(userSong)
        try context.save()

        let keptRowIDs: [String: UUID] = [
            "plim-plim": legacySongs.first { $0.title == "Plim Plim (Salta l'Esquirol)" }!.id,
            "twinkle-twinkle": legacySongs.first { $0.title == "Twinkle Twinkle Little Star" }!.id,
            "old-macdonald": legacySongs.first { $0.title == "Old MacDonald" }!.id,
            "sol-solet": legacySongs.first { $0.title == "Sol Solet" }!.id,
        ]

        SeedData.seedIfNeeded(context: context)

        let songs = try context.fetch(FetchDescriptor<Song>())
        let bundle = SeedData.createSeedSongs()

        // 13 current songs + 1 user song, nothing else.
        XCTAssertEqual(songs.count, bundle.count + 1,
                       "expected exactly the current catalog plus the user song")

        // The 5 dropped legacy songs are gone.
        for zombie in ["Hot Cross Buns", "Mary Had a Little Lamb", "Frère Jacques",
                       "Deniz's Lullaby", "La Castanyera"] {
            XCTAssertFalse(songs.contains { $0.title == zombie },
                           "legacy song \"\(zombie)\" survived the upgrade")
        }

        // Every current seed is present with fresh bundle content.
        for seed in bundle {
            let stored = try XCTUnwrap(songs.first { $0.seedID == seed.seedID },
                                       "seed \(seed.seedID ?? "?") missing after upgrade")
            XCTAssertEqual(stored.title, seed.title)
            XCTAssertEqual(stored.bpm, seed.bpm)
            XCTAssertTrue(stored.notes.musicallyEquals(seed.notes),
                          "\(seed.title) content not refreshed from bundle")
            XCTAssertEqual(stored.difficultyRank, seed.difficultyRank)
            XCTAssertEqual(stored.sortOrder, seed.sortOrder)
        }

        // Carried-over songs were adopted in place: same rows (simulated
        // progress carrier), now tagged with their seedIDs.
        for (seedID, rowID) in keptRowIDs {
            XCTAssertEqual(songs.first { $0.seedID == seedID }?.id, rowID,
                           "\(seedID) was reinserted instead of adopted — state would be lost")
        }

        // The user song is untouched.
        let user = try XCTUnwrap(songs.first { $0.id == userSong.id },
                                 "user song lost during upgrade")
        XCTAssertNil(user.seedID)
        XCTAssertEqual(user.bpm, 123)
        XCTAssertTrue(user.notes.musicallyEquals(userNotes))
    }

    // Seeding stays idempotent after an upgrade: a second pass changes nothing.
    func testUpgradedStoreIsStableAcrossRepeatedSeeding() throws {
        let context = try freshContext()
        for song in Build6Store.allSongs() { context.insert(song) }
        try context.save()

        SeedData.seedIfNeeded(context: context)
        let after1 = try context.fetch(FetchDescriptor<Song>())
        SeedData.seedIfNeeded(context: context)
        let after2 = try context.fetch(FetchDescriptor<Song>())

        XCTAssertEqual(after1.count, after2.count, "second pass changed the store")
        XCTAssertEqual(Set(after1.map(\.id)), Set(after2.map(\.id)),
                       "second pass replaced rows")
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

// MARK: - Build-6 store fixture

/// The seed catalog exactly as build 6 shipped it (git 342fe23, verbatim from
/// that revision's SeedData.swift): 9 songs, seeded by title — the seedID /
/// language / difficultyRank fields did not exist yet. This fixture is the
/// upgrade-path test gate for #35; it must stay frozen even when the live
/// catalog changes.
enum Build6Store {

    static func allSongs() -> [Song] {
        let songs = [
            hotCrossBuns(),
            maryHadALittleLamb(),
            twinkleTwinkleLittleStar(),
            oldMacDonald(),
            frereJacques(),
            denizsLullaby(),
            plimPlim(),
            laCastanyera(),
            solSolet(),
        ]
        for (index, song) in songs.enumerated() {
            song.sortOrder = index
        }
        return songs
    }

    static func hotCrossBuns() -> Song {
        Song(
            title: "Hot Cross Buns",
            bpm: 80,
            notes: [
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )
    }

    static func maryHadALittleLamb() -> Song {
        Song(
            title: "Mary Had a Little Lamb",
            bpm: 90,
            notes: [
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .whole),
            ]
        )
    }

    static func twinkleTwinkleLittleStar() -> Song {
        Song(
            title: "Twinkle Twinkle Little Star",
            bpm: 80,
            notes: [
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
            ]
        )
    }

    static func oldMacDonald() -> Song {
        Song(
            title: "Old MacDonald",
            bpm: 100,
            notes: [
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .quarter),
                NoteEntry(solfege: .La, octave: 3, duration: .quarter),
                NoteEntry(solfege: .La, octave: 3, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .half),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .quarter),
                NoteEntry(solfege: .La, octave: 3, duration: .quarter),
                NoteEntry(solfege: .La, octave: 3, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .half),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )
    }

    static func frereJacques() -> Song {
        Song(
            title: "Frère Jacques",
            bpm: 90,
            notes: [
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )
    }

    static func denizsLullaby() -> Song {
        Song(
            title: "Deniz's Lullaby",
            bpm: 60,
            notes: [
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
                NoteEntry(solfege: .Do, octave: 4, duration: .whole),
            ]
        )
    }

    static func laCastanyera() -> Song {
        Song(
            title: "La Castanyera",
            bpm: 90,
            notes: [
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )
    }

    static func plimPlim() -> Song {
        Song(
            title: "Plim Plim (Salta l'Esquirol)",
            bpm: 60,
            notes: [
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Si, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 5, duration: .half),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Si, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 5, duration: .half),
            ]
        )
    }

    static func solSolet() -> Song {
        Song(
            title: "Sol Solet",
            bpm: 75,
            notes: [
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )
    }
}
