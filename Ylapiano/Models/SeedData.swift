import Foundation
import SwiftData

struct SeedData {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Song>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingByTitle = Dictionary(uniqueKeysWithValues: existing.map { ($0.title, $0) })

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
        let songs = [plimPlim(), laCastanyera(), solSolet()]
        for (index, song) in songs.enumerated() {
            song.sortOrder = index
        }
        return songs
    }

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
