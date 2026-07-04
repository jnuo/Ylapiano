import Foundation
import SwiftData

struct SeedData {
    /// Canonical (stored) seed titles by seedID, built once.
    private static let canonicalTitles: [String: String] = Dictionary(
        uniqueKeysWithValues: createSeedSongs().compactMap { song in
            song.seedID.map { ($0, song.title) }
        }
    )

    /// Display titles per language, keyed by seedID. Languages not listed fall
    /// back to the canonical (stored) seed title. Placeholder translations —
    /// final wording lands with B2 (catalog) / B13 (Turkish).
    private static let localizedTitles: [String: [String: String]] = [
        "plim-plim": [
            "tr": "Plim Plim (Zıpla Sincap)",
            "en": "Plim Plim (Jump, Little Squirrel)",
        ],
    ]

    static func localizedTitle(seedID: String, locale: Locale) -> String? {
        guard let canonical = canonicalTitles[seedID] else { return nil }
        let lang = locale.language.languageCode?.identifier ?? ""
        return localizedTitles[seedID]?[lang] ?? canonical
    }

    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Song>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let seeds = createSeedSongs()

        // One-time adoption for build-6 stores, whose seeds predate seedID.
        // A song is recognized as ours only if title, bpm AND note content all
        // match the shipped seed — a user song differing in any of them stays
        // untouched.
        for seed in seeds {
            guard let seedID = seed.seedID else { continue }
            let seedNotes = seed.notes
            if let legacy = existing.first(where: {
                $0.seedID == nil
                    && $0.title == seed.title
                    && $0.bpm == seed.bpm
                    && $0.notes.musicallyEquals(seedNotes)
            }) {
                legacy.seedID = seedID
                legacy.language = seed.language
                legacy.difficultyRank = seed.difficultyRank
            }
        }

        // Keyed on seedID, never title: titles can change between builds, and
        // user-created songs may share a seed's title. seedID == nil → user song.
        let existingBySeedID = Dictionary(
            existing.compactMap { song in song.seedID.map { ($0, song) } },
            uniquingKeysWith: { first, _ in first }
        )

        for seed in seeds {
            guard let seedID = seed.seedID else { continue }
            if let current = existingBySeedID[seedID] {
                current.sortOrder = seed.sortOrder
            } else {
                context.insert(seed)
            }
        }
        try? context.save()
    }

    static func createSeedSongs() -> [Song] {
        // The locked 13 — product/decisions/2026-06-10-song-list.md.
        let songs = [
            // Catalan (5)
            plimPlim(),
            solSolet(),
            cargolTreuBanya(),
            laLlunaLaPruna(),
            elLleoNoEmFaPor(),
            // Turkish (4)
            kirmiziBalik(),
            aliBabaninCiftligi(),
            miniMiniBirKus(),
            portakaliSoydum(),
            // English (4)
            oldMacDonald(),
            twinkleTwinkleLittleStar(),
            wheelsOnTheBus(),
            itsyBitsySpider(),
        ]
        for (index, song) in songs.enumerated() {
            song.sortOrder = index
        }
        return songs
    }

    // MARK: - English (4)

    /// Twinkle Twinkle Little Star — full first verse. C major, 2/4, 80 BPM.
    private static func twinkleTwinkleLittleStar() -> Song {
        Song(
            title: "Twinkle Twinkle Little Star",
            bpm: 80,
            seedID: "twinkle-twinkle",
            language: "en",
            difficultyRank: 1,
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
            seedID: "old-macdonald",
            language: "en",
            difficultyRank: 2,
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

    /// The Wheels on the Bus — traditional. G major → C major, 4/4 felt, 95 BPM.
    /// Source: en.wikipedia.org/wiki/The_Wheels_on_the_Bus (LilyPond score).
    /// Approximations: "on the" 16th pair → eighth pair; dotted-8th+16th on
    /// "round (the)" / "through the" → even pairs.
    private static func wheelsOnTheBus() -> Song {
        Song(
            title: "The Wheels on the Bus",
            bpm: 95,
            seedID: "wheels-on-the-bus",
            language: "en",
            difficultyRank: 3,
            notes: [
                // "The"
                NoteEntry(solfege: .Sol, octave: 3, duration: .quarter),
                // "wheels on the bus go round and round"
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                // "round and round"
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
                // "round and round"
                NoteEntry(solfege: .Si, octave: 3, duration: .quarter),
                NoteEntry(solfege: .La, octave: 3, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .half),
                // "The wheels on the bus go round and round"
                NoteEntry(solfege: .Sol, octave: 3, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                // "All through the town"
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 3, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )
    }

    /// Itsy Bitsy Spider — traditional, 6/8. G major → C major, 90 BPM.
    /// Source: en.wikipedia.org/wiki/Itsy_Bitsy_Spider (LilyPond score),
    /// cross-checked with merriammusic.com letter notes (C major).
    /// 6/8 kept via dotted durations (one 6/8 bar = 3 app beats); final tie
    /// simplified to a dotted half.
    private static func itsyBitsySpider() -> Song {
        Song(
            title: "Itsy Bitsy Spider",
            bpm: 90,
            seedID: "itsy-bitsy-spider",
            language: "en",
            difficultyRank: 4,
            notes: [
                // "The"
                NoteEntry(solfege: .Sol, octave: 3, duration: .eighth),
                // "it-sy bit-sy"
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                // "spi-der climbed"
                NoteEntry(solfege: .Mi, octave: 4, duration: .dottedQuarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                // "up the wa-ter"
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                // "spout"
                NoteEntry(solfege: .Do, octave: 4, duration: .dottedHalf),
                // "Down came the"
                NoteEntry(solfege: .Mi, octave: 4, duration: .dottedQuarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                // "rain and"
                NoteEntry(solfege: .Sol, octave: 4, duration: .dottedQuarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .dottedQuarter),
                // "washed the spi-der"
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                // "out"
                NoteEntry(solfege: .Mi, octave: 4, duration: .dottedHalf),
                // "Out came the"
                NoteEntry(solfege: .Do, octave: 4, duration: .dottedQuarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                // "sun and"
                NoteEntry(solfege: .Mi, octave: 4, duration: .dottedQuarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .dottedQuarter),
                // "dried up all the"
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                // "rain — And the"
                NoteEntry(solfege: .Do, octave: 4, duration: .dottedQuarter),
                NoteEntry(solfege: .Si, octave: 3, duration: .quarter),
                NoteEntry(solfege: .Si, octave: 3, duration: .eighth),
                // "it-sy bit-sy"
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                // "spi-der climbed"
                NoteEntry(solfege: .Mi, octave: 4, duration: .dottedQuarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                // "up the spout a-"
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                // "-gain"
                NoteEntry(solfege: .Do, octave: 4, duration: .dottedHalf),
            ]
        )
    }

    // MARK: - Turkish (4)

    /// Kırmızı Balık — traditional Turkish. C major, 4/4 felt, 90 BPM.
    /// Pitches: kolaynota.com + muziknotalari.com.tr (agree across 3 keys);
    /// only Do-Re-Mi — the easiest song in the catalog. Rhythm is NOT
    /// documented by any source — set by feel, ear-verify (B2 sub-task 4).
    private static func kirmiziBalik() -> Song {
        Song(
            title: "Kırmızı Balık",
            bpm: 90,
            seedID: "kirmizi-balik",
            language: "tr",
            difficultyRank: 1,
            notes: [
                // "Kır-mı-zı ba-lık göl-de"
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
                // "kıv-rı-la kıv-rı-la yü-zü-yor"
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
                // "ba-lık-çı Ha-san ge-li-yor"
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
                // "ol-ta-sı-nı a-tı-yor"
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
            ]
        )
    }

    /// Ali Baba'nın Çiftliği — Turkish farm song. F major → C major, 100 BPM.
    /// Pitches: kolaynota.com (F), cross-checked muziknotalari.com (G) —
    /// contours match. NOTE: this is NOT the Old MacDonald tune (decision
    /// file assumed it was) and is locally credited to Erdoğan Çaplı — PD
    /// status flagged for Onur. Rhythm undocumented — set by feel.
    private static func aliBabaninCiftligi() -> Song {
        Song(
            title: "Ali Baba'nın Çiftliği",
            bpm: 100,
            seedID: "ali-babanin-ciftligi",
            language: "tr",
            difficultyRank: 4,
            notes: [
                // "A-li Ba-ba-nın bir çift-li-ği var"
                NoteEntry(solfege: .Sol, octave: 3, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Si, octave: 3, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
                // "çift-li-ğin-de i-nek-le-ri var"
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                // "mööö mööö di-ye ba-ğı-rır"
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                // "çift-li-ğin-de A-li Ba-ba-nın"
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .half),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .whole),
            ]
        )
    }

    /// Mini Mini Bir Kuş — traditional Turkish lullaby. C major, 85 BPM.
    /// Pitches: kolaynota.com + muziknotalari.com.tr + flutnotalari (3 keys
    /// agree on the verse). Middle section single-sourced. Rhythm
    /// undocumented — set by feel, ear-verify.
    private static func miniMiniBirKus() -> Song {
        Song(
            title: "Mini Mini Bir Kuş",
            bpm: 85,
            seedID: "mini-mini-bir-kus",
            language: "tr",
            difficultyRank: 2,
            notes: [
                // "Mi-ni mi-ni bir kuş don-muş-tu"
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                // "pen-ce-re-me kon-muş-tu"
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
                // "Al-dım o-nu i-çe-ri-ye"
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                // "cik cik cik cik ö-tü-yor-du"
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )
    }

    /// Portakalı Soydum — Turkish tekerleme (counting-out rhyme). C major, 95 BPM.
    /// NO canonical melody exists (research 2026-06-12: every recording sets
    /// its own; education sites publish only the rhyme). Set here as the
    /// classic playground sol-mi chant. TOP ear-check priority — Onur
    /// confirms at the piano or we swap the setting.
    private static func portakaliSoydum() -> Song {
        Song(
            title: "Portakalı Soydum",
            bpm: 95,
            seedID: "portakali-soydum",
            language: "tr",
            difficultyRank: 3,
            notes: [
                // "Por-ta-ka-lı soy-dum"
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                // "Ba-şu-cu-ma koy-dum"
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                // "Ben bir ya-lan uy-dur-dum"
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .half),
                // "Du-ma du-ma dum"
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                // "Kır-mı-zı mum"
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .half),
            ]
        )
    }

    // MARK: - Catalan (5)

    /// Cargol, treu banya — Catalan, music Mas i Serracant (~1909, PD).
    /// G major → C major, 2/4, 85 BPM. Source: xipxap.wordpress.com score
    /// scan, cross-checked blocs.xtec.cat (same engraving).
    /// Approximations: dotted-8th+16th on "pu-ja" → even eighths; keeps the
    /// engraving's quarter rest after "vi".
    private static func cargolTreuBanya() -> Song {
        Song(
            title: "Cargol, treu banya",
            bpm: 85,
            seedID: "cargol-treu-banya",
            language: "ca",
            difficultyRank: 3,
            notes: [
                // "Car-gol, treu ba-nya,"
                NoteEntry(solfege: .Sol, octave: 3, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 3, duration: .quarter),
                // "pu-ja a la mun-ta-nya;"
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Si, octave: 3, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .La, octave: 3, duration: .eighth),
                // "car-gol, treu vi,"
                NoteEntry(solfege: .La, octave: 3, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter, isRest: true),
                // "pu-ja al mun-ta-nyí."
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
            ]
        )
    }

    /// La lluna, la pruna — Catalan (Maideu, Crestomatia; XTEC school
    /// version). Original is modal on A with a B♭ — mapped to E-Phrygian on
    /// white keys (same intervals), 2/4, 95 BPM. Ends on Mi, not Do — that's
    /// the tune, not a bug. Source: xtec.cat 180es.mid + score GIF.
    private static func laLlunaLaPruna() -> Song {
        Song(
            title: "La lluna, la pruna",
            bpm: 95,
            seedID: "la-lluna-la-pruna",
            language: "ca",
            difficultyRank: 5,
            notes: [
                // "La llu-na, la pru-na,"
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                // "ves-ti-da de dol;"
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .dottedQuarter),
                // "el pa-re la cri-da,"
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                // "la ma-re la vol."
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Fa, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
            ]
        )
    }

    /// El lleó no em fa por — Catalan, music Ireneu Segarra (songbook print).
    /// F major → C major, 2/4, 90 BPM. Source: elpetitracodemusica.blogspot
    /// score scan, structure cross-checked on flat.io. Final "dor" lengthened
    /// quarter → half for closure.
    private static func elLleoNoEmFaPor() -> Song {
        Song(
            title: "El lleó no em fa por",
            bpm: 90,
            seedID: "el-lleo-no-em-fa-por",
            language: "ca",
            difficultyRank: 4,
            notes: [
                // "El lle-ó no em fa por,"
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                // "pam i pi-pa, pam i pi-pa,"
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                // "el lle-ó no em fa por"
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
                // "per-què sóc bon ca-ça-dor."
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Do, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Re, octave: 4, duration: .eighth),
                NoteEntry(solfege: .Mi, octave: 4, duration: .eighth),
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
            seedID: "sol-solet",
            language: "ca",
            difficultyRank: 2,
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
