import Foundation
import SwiftData

struct SeedData {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Song>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let songs = createSeedSongs()
        for song in songs {
            context.insert(song)
        }
        try? context.save()
    }

    static func createSeedSongs() -> [Song] {

        // Plim Plim (Salta l'Esquirol) — Traditional Catalan children's song
        // Key: F major, transposed to C. Time: 2/4. BPM: 90.
        // Source: xipxap.wordpress.com/2015/12/28/lesquirol/
        // Pattern: Do(q) Mi(8) Fa(8) | Sol(h) | for each "plim plim plim plim"
        let plimPlim = Song(
            title: "Plim Plim (Salta l'Esquirol)",
            bpm: 90,
            notes: [
                // "Plim plim plim plim" — Do(q) Mi(8) Fa(8) | Sol(h)
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                // "salta l'esquirol" — La(8) Sol(8) Fa(8) La(8) | Sol(h)
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                // "plim plim plim plim" — Do(q) Mi(8) Fa(8) | Sol(h)
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                // "i depressa puja al tronc" — La(8) Sol(8) La(8) Sol(8) | La(q) Si(q) | Do5(h)
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Si, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 5, duration: .half),
                // "plim plim plim plim" — Do(q) Mi(8) Fa(8) | Sol(h)
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                // "agafa una pinya" — La(8) Sol(8) Fa(8) La(8) | Sol(h)
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                // "plim plim plim plim" — Do(q) Mi(8) Fa(8) | Sol(h)
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                // "i se la menja tot sol" — La(8) Sol(8) La(8) Sol(8) | La(q) Si(q) | Do5(h)
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Si, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 5, duration: .half),
            ]
        )

        return [plimPlim]
    }
}
