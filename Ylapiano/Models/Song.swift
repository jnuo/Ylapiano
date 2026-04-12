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

    var id: String { rawValue }

    var beats: Double {
        switch self {
        case .whole: return 4.0
        case .half: return 2.0
        case .quarter: return 1.0
        case .eighth: return 0.5
        }
    }

    var displayName: String {
        switch self {
        case .whole: return "Whole"
        case .half: return "Half"
        case .quarter: return "Quarter"
        case .eighth: return "Eighth"
        }
    }

    var symbol: String {
        switch self {
        case .whole: return "𝅝"
        case .half: return "𝅗𝅥"
        case .quarter: return "♩"
        case .eighth: return "♪"
        }
    }
}

// MARK: - NoteEntry

struct NoteEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var solfege: Solfege
    var octave: Int
    var duration: NoteDuration

    /// Convert to ABC notation pitch
    var abcPitch: String {
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
        }
    }
}

extension Array where Element == NoteEntry {
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
            lyricsLine += " " + (useSolfege ? note.solfege.rawValue : note.solfege.cde)
            currentBeats += note.duration.beats
            if currentBeats >= beatsPerMeasure {
                noteLine += "|"
                currentBeats = 0
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

    var notes: [NoteEntry] {
        get {
            (try? JSONDecoder().decode([NoteEntry].self, from: notesData)) ?? []
        }
        set {
            notesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    init(id: UUID = UUID(), title: String, bpm: Int, notes: [NoteEntry] = []) {
        self.id = id
        self.title = title
        self.bpm = bpm
        self.notesData = (try? JSONEncoder().encode(notes)) ?? Data()
    }
}
