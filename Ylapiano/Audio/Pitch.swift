import Foundation

/// A musical pitch identified by its MIDI note number.
///
/// Introduced so MIDI integers don't leak through every layer that handles
/// notes — on-screen keyboard, sampler, MIDI input, falling-notes scene.
/// Construct from raw MIDI (`Pitch(midi: 60)`) or solfège + octave
/// (`Pitch(solfege: .Do, octave: 4)`); both inits land at the same MIDI value.
struct Pitch: Hashable, Sendable {
    /// MIDI note number — middle C = 60, A4 = 69, range 0…127.
    let midi: UInt8

    init(midi: UInt8) {
        self.midi = midi
    }

    init(solfege: Solfege, octave: Int) {
        self.midi = UInt8(clamping: solfege.midiNote(octave: octave))
    }

    /// Octave number per MIDI convention (middle C / MIDI 60 = octave 4).
    var octave: Int {
        Int(midi) / 12 - 1
    }

    /// Solfège name if this pitch falls on a natural (white) key — `nil` for
    /// sharps and flats. Useful for solfège-vs-letter UI but not required.
    var solfege: Solfege? {
        let semitone = Int(midi) % 12
        return Solfege.allCases.first { $0.semitoneOffset == semitone }
    }

    /// Equal-tempered frequency in Hz (A4 = 440).
    var frequency: Double {
        440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
    }

    /// `true` when this pitch sits on a black key (sharp).
    var isSharp: Bool {
        let semitone = Int(midi) % 12
        return [1, 3, 6, 8, 10].contains(semitone)
    }
}
