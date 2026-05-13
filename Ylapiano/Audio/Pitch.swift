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

    /// Column index (0-based) of this pitch on a white-keys-only keyboard that
    /// starts at `startOctave`'s C and spans `octaveCount` full octaves plus
    /// one trailing top-C — the layout `PianoKeyboardView` already renders.
    /// Returns `nil` for sharps or pitches outside the rendered range so the
    /// falling-notes scene can simply skip them.
    ///
    /// Indexing: for `octaveCount = 2` lanes are 0…14 (15 keys total),
    /// where 0 = startOctave-C and 14 = top-C. The bound is inclusive
    /// because `octaveCount * 7` is the index of the trailing top-C, not
    /// the count of keys.
    func whiteKeyLane(startOctave: Int = 3, octaveCount: Int = 2) -> Int? {
        // Within an octave: C=0, D=1, E=2, F=3, G=4, A=5, B=6; sharps = nil.
        let semitoneToWhite: [Int?] = [0, nil, 1, nil, 2, 3, nil, 4, nil, 5, nil, 6]
        let semitone = Int(midi) % 12
        guard let whiteWithinOctave = semitoneToWhite[semitone] else { return nil }
        let lane = (octave - startOctave) * 7 + whiteWithinOctave
        let lastLaneIndex = octaveCount * 7   // index of the trailing top-C
        guard lane >= 0, lane <= lastLaneIndex else { return nil }
        return lane
    }
}
