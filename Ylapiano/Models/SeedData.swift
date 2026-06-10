import Foundation
import SwiftData

struct SeedData {
    /// Titles we used to seed but have since cut. Pruned from any existing
    /// store so the app shows only the one song in active use. (Re-add from git
    /// history when the repertoire grows again.)
    private static let retiredSeedTitles: Set<String> = [
        "Hot Cross Buns", "Mary Had a Little Lamb", "Twinkle Twinkle Little Star",
        "Old MacDonald", "Frère Jacques", "Deniz's Lullaby", "La Castanyera", "Sol Solet"
    ]

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Song>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingByTitle = Dictionary(existing.map { ($0.title, $0) }, uniquingKeysWith: { first, _ in first })

        // Remove the songs we no longer ship (leaves any user-added songs alone).
        for song in existing where retiredSeedTitles.contains(song.title) {
            context.delete(song)
        }

        for seed in createSeedSongs() {
            if let current = existingByTitle[seed.title] {
                current.sortOrder = seed.sortOrder
            } else {
                context.insert(seed)
            }
        }
        try? context.save()
    }

    static func createSeedSongs() -> [Song] {
        // One song while we get the falling-notes game right. The other tunes'
        // builders are kept below (unused) so they're easy to bring back.
        let songs = [plimPlim()]
        for (index, song) in songs.enumerated() {
            song.sortOrder = index
        }
        return songs
    }

    // MARK: - PLAN.md v1 Repertoire

    /// Hot Cross Buns — classic 3-note teaching tune (Mi-Re-Do).
    /// Key C major, 2/4, 80 BPM. RH only.
    private static func hotCrossBuns() -> Song {
        Song(
            title: "Hot Cross Buns",
            bpm: 80,
            notes: [
                // "Hot cross buns"
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                // "Hot cross buns"
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                // "One a penny, two a penny"
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                // "Hot cross buns"
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )
    }

    /// Mary Had a Little Lamb — full first verse. C major, 2/4, 90 BPM.
    private static func maryHadALittleLamb() -> Song {
        Song(
            title: "Mary Had a Little Lamb",
            bpm: 90,
            notes: [
                // "Ma-ry had a"
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                // "lit-tle lamb"
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                // "lit-tle lamb"
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
                // "lit-tle lamb"
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                // "Ma-ry had a lit-tle lamb"
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                // "Whose fleece was white as snow"
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .whole),
            ]
        )
    }

    /// Twinkle Twinkle Little Star — full first verse. C major, 2/4, 80 BPM.
    private static func twinkleTwinkleLittleStar() -> Song {
        Song(
            title: "Twinkle Twinkle Little Star",
            bpm: 80,
            notes: [
                // "Twin-kle twin-kle"
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // "lit-tle star"
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                // "How I won-der"
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                // "what you are"
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                // "Up a-bove the world so high"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
                // "Like a dia-mond in the sky"
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

    /// Old MacDonald — verse + E-I-E-I-O refrain (one round). C major, 2/4, 100 BPM.
    private static func oldMacDonald() -> Song {
        Song(
            title: "Old MacDonald",
            bpm: 100,
            notes: [
                // "Old Mac-Don-ald had a"
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .quarter),
                NoteEntry(solfege: .La, octave: 3, duration: .quarter),
                NoteEntry(solfege: .La, octave: 3, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .half),
                // "E-I-E-I-O"
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                // "And on that farm he had a"
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .quarter),
                NoteEntry(solfege: .La, octave: 3, duration: .quarter),
                NoteEntry(solfege: .La, octave: 3, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .half),
                // "E-I-E-I-O"
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )
    }

    /// Frère Jacques — round in C major, 2/4, 90 BPM. Ends on a low Sol3 → Do4
    /// "bell" pattern that exercises the bottom of the 3-octave range.
    private static func frereJacques() -> Song {
        Song(
            title: "Frère Jacques",
            bpm: 90,
            notes: [
                // "Frè-re Jac-ques" ×2
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                // "Dor-mez vous?" ×2
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                // "Son-nez les ma-ti-nes" ×2
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
                // "Ding dang dong" ×2
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )
    }

    /// Deniz's Lullaby — original placeholder composition in C major, 2/4, 60 BPM.
    /// Simple descending pentatonic-flavored lullaby. Replace with the real
    /// Deniz melody once written.
    private static func denizsLullaby() -> Song {
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

    // MARK: - Pre-v1 Catalan Tunes (kept for continuity)

    // La Castanyera — Traditional Catalan autumn song (simplified)
    // Simplified: C major, 2/4, only quarter and half notes.
    // First phrase: "Quan ve el temps de collir castanyes la castanyera"
    private static func laCastanyera() -> Song {
        Song(
            title: "La Castanyera",
            bpm: 90,
            notes: [
                // "Quan ve el temps"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                // "de co-llir"
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // "cas-ta-nyes"
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                // "la cas-ta-nye-ra"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )
    }

    // Plim Plim (Salta l'Esquirol) — Traditional Catalan children's song
    // Key: F major, transposed to C. Time: 2/4. BPM: 60.
    // Source: xipxap.wordpress.com/2015/12/28/lesquirol/
    private static func plimPlim() -> Song {
        Song(
            title: "Plim Plim (Salta l'Esquirol)",
            bpm: 60,
            seedID: "plim-plim",
            language: "ca",
            difficultyRank: 1,
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

    // Sol Solet — Traditional Catalan children's lullaby-style song
    // Key: C major, Time: 2/4. Triplets simplified to eighth pairs.
    // Note: original has eighth-note triplets on "vi-ne'm-a" — transcribed as
    // two eighths since the app doesn't support triplets.
    private static func solSolet() -> Song {
        Song(
            title: "Sol Solet",
            bpm: 75,
            notes: [
                // "Sol, so-"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // "-let vi-ne'm-a"
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                // "veu-re, vi-ne'm-a"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                // "veu- re"
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // Second half: "Sol, so-let vi-ne'm-a veu-re que tinc fred"
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
