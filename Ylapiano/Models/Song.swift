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

    var displayName: String {
        "\(solfege.rawValue)\(octave)"
    }

    var cdeName: String {
        "\(solfege.cde)\(octave)"
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
