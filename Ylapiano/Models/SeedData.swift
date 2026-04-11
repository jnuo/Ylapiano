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

        // 1. Plim Plim (Salta l'Esquirol) — Traditional Catalan children's song
        // Key: C major. Chords: C, F, G. Bouncy squirrel melody.
        // "Plim plim plim plim, salta l'esquirol..."
        // The "plim" motif sits on Sol, melody descends through Mi-Re-Do
        let plimPlim = Song(
            title: "Plim Plim (Salta l'Esquirol)",
            bpm: 120,
            notes: [
                // "Plim plim plim plim" — repeated Sol
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // "salta l'esquirol" — descending
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                // "Plim plim plim plim"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // "i depressa puja al tronc"
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                // "Plim plim plim plim"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // "agafa una pinya"
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                // "Plim plim plim plim"
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // "i se la menja tot sol"
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )

        // 2. La Castanyera — Catalan chestnut seller song
        // From Pep Puigdemont score: D major, 3/4, ♩=144
        // Transposed to C major (D→C, E→D, F#→E, A→G)
        // Chords: I(C), IV(F), V(G)
        let laCastanyera = Song(
            title: "La Castanyera",
            bpm: 110,
            notes: [
                // "Quan ve el temps" — ascending from Do
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                // "de collir castanyes" — up to Sol then back
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                // "la castanyera" — stepwise around Re-Mi
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                // "la castanyera" — repeat
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                // "ve contenta" — similar contour
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                // "de la muntanya" — up to Sol
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                // "amb el cistellet penjant del braç" — cadence to Do
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )

        // 3. Cargol Treu Banya — "Snail, show your horns"
        // Traditional Catalan. Key: C major. Chords: C, G. Andante.
        // 2/4 time. Ascending melody (snail climbing the mountain)
        // "Cargol, treu banya, puja a la muntanya"
        let cargolTreuBanya = Song(
            title: "Cargol Treu Banya",
            bpm: 100,
            notes: [
                // "Cargol treu banya" — ascending stepwise
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                // "puja a la muntanya" — up to Sol
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .half),
                // "cargol treu vi" — ascending again
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                // "puja al muntanyí" — resolve down
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )

        // 4. Marrameu — Catalan cat song
        // Playful melody with "meu meu" (meow) motif
        // Key: C major, moderate tempo
        let marrameu = Song(
            title: "Marrameu",
            bpm: 105,
            notes: [
                // "Marrameu" — bouncy third intervals
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // "on vas amb aqueix gat"
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                // "Marrameu"
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                // "que em fa molta por"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )

        // 5. Bim Bom (Les Campanes de Salom) — Catalan lap game song
        // Uses only TWO notes: Sol and Do (confirmed by pedagogical sources)
        // 2/4 time, gentle rocking pace. "Bim bom, les campanes de Salom"
        let bimBom = Song(
            title: "Bim Bom",
            bpm: 85,
            notes: [
                // "Bim bom" — Sol-Do rocking pattern
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                // "les campanes"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                // "de Salom"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                // repeat — "Bim bom"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                // "les campanes"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                // "de Salom"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )

        // 6. Pon, Titeta, Pon — Catalan chant/lap game
        // Traditionally a spoken chant ("cantarella sense musica")
        // Melodized here using Sol-Mi chanting tradition (universal children's call)
        let ponTitetaPon = Song(
            title: "Pon, Titeta, Pon",
            bpm: 100,
            notes: [
                // "Pon" — Sol
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // "ti-te-ta" — Sol-Mi-Sol
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // "pon" — Mi
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                // "pon" — Sol
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // "ti-te-ta" — Sol-Mi-Sol
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // "pon" — Mi
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                // "pon" — La (higher for contrast)
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                // "ti-te-ta" — Sol-Mi-Sol
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                // final "pon" — Do (cadence)
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )

        // 7. El Gall i la Gallina — The rooster and the hen
        // Ascending rooster call, key: C major
        let elGall = Song(
            title: "El Gall i la Gallina",
            bpm: 105,
            notes: [
                // "El gall" — ascending arpeggio (crowing)
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                // "i la gallina"
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
                // "fan ous a la cuina" — descending
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                // cadence
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )

        return [plimPlim, laCastanyera, cargolTreuBanya, marrameu, bimBom, ponTitetaPon, elGall]
    }
}
