import Foundation
import SwiftData

// MARK: - Solfège

enum Solfege: String, Codable, CaseIterable, Identifiable {
    case Do, Re, Mi, Fa, Sol, La, Si

    var id: String { rawValue }

    var cde: String {
        switch self {
        case .Do: return "C"
        case .Re: return "D"
        case .Mi: return "E"
        case .Fa: return "F"
        case .Sol: return "G"
        case .La: return "A"
        case .Si: return "B"
        }
    }

    /// Semitone offset within an octave (C=0)
    var semitoneOffset: Int {
        switch self {
        case .Do: return 0
        case .Re: return 2
        case .Mi: return 4
        case .Fa: return 5
        case .Sol: return 7
        case .La: return 9
        case .Si: return 11
        }
    }

    /// MIDI note number for a given octave (octave 4 → middle C = 60)
    func midiNote(octave: Int) -> Int {
        return (octave + 1) * 12 + semitoneOffset
    }

    /// Frequency in Hz for a given octave (A4 = 440 Hz)
    func frequency(octave: Int) -> Double {
        let midi = Double(midiNote(octave: octave))
        return 440.0 * pow(2.0, (midi - 69.0) / 12.0)
    }

    /// Staff position relative to middle C (C4 = 0). Each step = one line/space.
    func staffPosition(octave: Int) -> Int {
        let scaleIndex: Int = {
            switch self {
            case .Do: return 0
            case .Re: return 1
            case .Mi: return 2
            case .Fa: return 3
            case .Sol: return 4
            case .La: return 5
            case .Si: return 6
            }
        }()
        return (octave - 4) * 7 + scaleIndex
    }
}

// MARK: - Note Duration

enum NoteDuration: String, Codable, CaseIterable, Identifiable {
    case whole, half, quarter, eighth
    case dottedHalf, dottedQuarter, dottedEighth

    var id: String { rawValue }

    var beats: Double {
        switch self {
        case .whole: return 4.0
        case .half: return 2.0
        case .quarter: return 1.0
        case .eighth: return 0.5
        case .dottedHalf: return 3.0
        case .dottedQuarter: return 1.5
        case .dottedEighth: return 0.75
        }
    }

    var displayName: String {
        switch self {
        case .whole: return "Whole"
        case .half: return "Half"
        case .quarter: return "Quarter"
        case .eighth: return "Eighth"
        case .dottedHalf: return "Dotted Half"
        case .dottedQuarter: return "Dotted Quarter"
        case .dottedEighth: return "Dotted Eighth"
        }
    }

    var symbol: String {
        switch self {
        case .whole: return "𝅝"
        case .half: return "𝅗𝅥"
        case .quarter: return "♩"
        case .eighth: return "♪"
        case .dottedHalf: return "𝅗𝅥."
        case .dottedQuarter: return "♩."
        case .dottedEighth: return "♪."
        }
    }
}

// MARK: - NoteEntry

struct NoteEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var solfege: Solfege
    var octave: Int
    var duration: NoteDuration
    /// A rest: occupies time but plays no pitch. `solfege`/`octave` are
    /// ignored while true. Absent in pre-B2 (build ≤10) notesData JSON.
    var isRest: Bool = false

    init(id: UUID = UUID(), solfege: Solfege, octave: Int, duration: NoteDuration, isRest: Bool = false) {
        self.id = id
        self.solfege = solfege
        self.octave = octave
        self.duration = duration
        self.isRest = isRest
    }

    // Custom decode: build-≤10 blobs have no isRest key.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        solfege = try container.decode(Solfege.self, forKey: .solfege)
        octave = try container.decode(Int.self, forKey: .octave)
        duration = try container.decode(NoteDuration.self, forKey: .duration)
        isRest = try container.decodeIfPresent(Bool.self, forKey: .isRest) ?? false
    }

    /// Convert to ABC notation pitch ("z" = rest)
    var abcPitch: String {
        guard !isRest else { return "z" }
        let letter = solfege.cde
        switch octave {
        case 3: return letter + ","
        case 4: return letter
        case 5: return letter.lowercased()
        case 6: return letter.lowercased() + "'"
        default: return letter
        }
    }

    /// Convert to ABC notation with duration (relative to L:1/4)
    var abcString: String {
        switch duration {
        case .whole: return abcPitch + "4"
        case .half: return abcPitch + "2"
        case .quarter: return abcPitch
        case .eighth: return abcPitch + "/"
        case .dottedHalf: return abcPitch + "3"
        case .dottedQuarter: return abcPitch + "3/2"
        case .dottedEighth: return abcPitch + "3/4"
        }
    }
}

extension Array where Element == NoteEntry {
    /// Same musical content (pitch + duration sequence), ignoring entry UUIDs.
    /// Rests compare by duration only — their placeholder pitch is not music.
    func musicallyEquals(_ other: [NoteEntry]) -> Bool {
        count == other.count && zip(self, other).allSatisfy { a, b in
            guard a.duration == b.duration, a.isRest == b.isRest else { return false }
            return a.isRest || (a.solfege == b.solfege && a.octave == b.octave)
        }
    }

    /// Convert note array to ABC notation string
    func toABC(title: String = "", timeSignature: String = "2/4", key: String = "C", useSolfege: Bool = true, bpm: Int = 90, measuresPerLine: Int = 4) -> String {
        // Omit T: title — shown in nav bar instead. Keep Q: tempo for playback.
        var abc = "X:1\n"
        abc += "M:\(timeSignature)\nL:1/4\nQ:1/4=\(bpm)\nK:\(key)\n"

        let beatsPerMeasure: Double = timeSignature == "2/4" ? 2.0 : 4.0
        var currentBeats: Double = 0
        var measureCount = 0
        var noteLine = ""
        var lyricsLine = "w:"

        for note in self {
            noteLine += note.abcString + " "
            // ABC w: lyrics align to sounding notes only — a rest syllable
            // would shift every later label one note left.
            if !note.isRest {
                lyricsLine += " " + (useSolfege ? note.solfege.rawValue : note.solfege.cde)
            }
            currentBeats += note.duration.beats
            if currentBeats >= beatsPerMeasure {
                noteLine += "|"
                // Carry the overflow (dotted notes straddle the bar) so
                // barlines stay anchored to the beat grid.
                while currentBeats >= beatsPerMeasure { currentBeats -= beatsPerMeasure }
                measureCount += 1
                // Force line break in ABC after measuresPerLine bars
                if measureCount == measuresPerLine {
                    abc += noteLine + "\n" + lyricsLine + "\n"
                    noteLine = ""
                    lyricsLine = "w:"
                    measureCount = 0
                } else {
                    noteLine += " "
                }
            }
        }
        // Flush remainder
        if !noteLine.trimmingCharacters(in: .whitespaces).isEmpty {
            if currentBeats > 0 { noteLine += "|" }
            abc += noteLine + "\n" + lyricsLine + "\n"
        }
        // Append one empty line of rests so the last real line can scroll to top
        let emptyMeasure: String = timeSignature == "2/4" ? "z2" : "z4"
        var emptyLine: String = ""
        for _ in 0..<measuresPerLine {
            emptyLine += emptyMeasure + " | "
        }
        abc += emptyLine + "\n"
        return abc
    }
}

// MARK: - Song (SwiftData model)

@Model
final class Song {
    var id: UUID
    var title: String
    var bpm: Int
    var notesData: Data
    var sortOrder: Int = 0
    /// Stable identity for shipped seed songs; nil = user-created.
    /// Defaults keep the SwiftData migration from build 6 lightweight.
    var seedID: String? = nil
    var language: String? = nil
    var difficultyRank: Int = 0

    /// B3 progress — user STATE, never touched by SeedData.refreshContent.
    /// Best stars across all completed runs (0 = never finished) and highest
    /// mastery-ladder rung reached (0-based index; meaningful only where
    /// hasMasteryLadder). Only upgrades are ever written. Defaults keep the
    /// migration from earlier stores lightweight, same as seedID above.
    /// B9 reads these straight off the row for the home-screen cards.
    var bestStars: Int = 0
    var bestRung: Int = 0

    var isSeed: Bool { seedID != nil }

    /// The single mastery-ladder song (B4 #21). The ladder owns this song's
    /// tempo / guidance / timing windows; every other song plays the gentle
    /// fixed config. Lives on the model (not just `PlayerViewModel`) so the
    /// song editor can honestly mark its BPM field ladder-owned (B10, PR #33
    /// residual: editing Salta's BPM silently did nothing).
    var hasMasteryLadder: Bool { seedID == "plim-plim" }

    var notes: [NoteEntry] {
        get {
            (try? JSONDecoder().decode([NoteEntry].self, from: notesData)) ?? []
        }
        set {
            notesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(id: UUID = UUID(), title: String, bpm: Int,
         seedID: String? = nil, language: String? = nil, difficultyRank: Int = 0,
         notes: [NoteEntry] = [], sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.bpm = bpm
        self.notesData = (try? JSONEncoder().encode(notes)) ?? Data()
        self.sortOrder = sortOrder
        self.seedID = seedID
        self.language = language
        self.difficultyRank = difficultyRank
    }
}
