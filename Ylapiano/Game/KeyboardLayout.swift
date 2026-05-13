import Foundation

/// Single source of truth for the on-screen piano's keyboard geometry. Both
/// `PianoKeyboardView` (the actual touch surface) and `FallingNotesScene`
/// (whose lanes must line up 1:1 with white keys) read from this. Without
/// it the two would silently drift the next time anyone changes the range.
struct KeyboardLayout {
    /// Leftmost octave on the keyboard. Octave 3 places middle C / Do4 at
    /// lane index 7, near the visual center.
    let startOctave: Int
    /// Number of full octaves shown before the trailing top-C. Two octaves
    /// (`startOctave=3, octaveCount=2`) gives the 15-key C3 → C5 keyboard
    /// that covers every pitch in the v1 seed songs, including the low G3
    /// in Old MacDonald and the Sol3-Do4 bell in Frère Jacques.
    let octaveCount: Int

    /// The keyboard `PianoKeyboardView` renders today and `FallingNotesScene`
    /// pairs its lanes against. Change here, both update.
    static let `default` = KeyboardLayout(startOctave: 3, octaveCount: 2)

    /// Total white-key columns. `octaveCount * 7` natural notes plus the
    /// extra top-C that closes the range — `default` yields 15.
    var whiteKeyCount: Int { octaveCount * 7 + 1 }

    /// Lane index for a pitch, or `nil` if it's a sharp (no white-key
    /// column) or sits outside this layout's range.
    func laneIndex(for pitch: Pitch) -> Int? {
        pitch.whiteKeyLane(startOctave: startOctave, octaveCount: octaveCount)
    }
}
