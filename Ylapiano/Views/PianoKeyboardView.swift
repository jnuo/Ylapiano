import SwiftUI

struct PianoKeyboardView: View {
    let useSolfege: Bool
    let highlightedNote: Solfege?
    let highlightedOctave: Int?
    let expectedNote: NoteEntry?
    let isCorrect: Bool?
    let guidedMode: Bool
    /// Called when the user taps a key. Receives a typed `Pitch` so callers
    /// (sampler, future MIDI input, falling-notes scene) share one currency
    /// instead of bare MIDI integers. Default no-op keeps existing call
    /// sites compiling.
    var onKeyTap: (Pitch) -> Void = { _ in }

    // 3 octaves: C3-B5
    private let startOctave = 3
    private let octaveCount = 3
    private let blackKeyHeightRatio: CGFloat = 0.6

    /// MIDI numbers currently in their brief "just tapped" visual state.
    /// Each entry is removed automatically ~180 ms after insertion.
    @State private var pressedKeys: Set<UInt8> = []

    private var whiteKeys: [(Solfege, Int)] {
        var keys: [(Solfege, Int)] = []
        for octave in startOctave..<(startOctave + octaveCount) {
            for note in Solfege.allCases {
                keys.append((note, octave))
            }
        }
        // Add final C
        keys.append((.Do, startOctave + octaveCount))
        return keys
    }

    private var blackKeyIndices: Set<Int> {
        // Black keys appear after: Do(C#), Re(D#), Fa(F#), Sol(G#), La(A#)
        // In a 7-note solfège layout, that's after indices 0, 1, 3, 4, 5
        Set([0, 1, 3, 4, 5])
    }

    private let whiteKeyGap: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let totalGaps = CGFloat(whiteKeys.count - 1) * whiteKeyGap
            let keyWidth = (geo.size.width - totalGaps) / CGFloat(whiteKeys.count)
            let keyHeight = geo.size.height
            let bkWidth = keyWidth * 0.65
            let bkHeight = keyHeight * blackKeyHeightRatio

            ZStack(alignment: .topLeading) {
                // White keys
                HStack(spacing: whiteKeyGap) {
                    ForEach(Array(whiteKeys.enumerated()), id: \.offset) { _, key in
                        whiteKeyView(note: key.0, octave: key.1, keyWidth: keyWidth, keyHeight: keyHeight)
                    }
                }

                // Black keys
                blackKeysOverlay(keyWidth: keyWidth, bkWidth: bkWidth, bkHeight: bkHeight)
            }
        }
    }

    // MARK: - White Key

    private func whiteKeyView(note: Solfege, octave: Int, keyWidth: CGFloat, keyHeight: CGFloat) -> some View {
        let pitch = Pitch(solfege: note, octave: octave)
        let isHighlighted = highlightedNote == note && highlightedOctave == octave
        let isExpected = guidedMode && expectedNote?.solfege == note && expectedNote?.octave == octave
        let matchesExpectedPitch = highlightedNote == note // Match regardless of octave for young learners
        let isPressed = pressedKeys.contains(pitch.midi)

        let backgroundColor: Color = {
            if isHighlighted {
                if let isCorrect {
                    return isCorrect ? Color.green.opacity(0.7) : Color.red.opacity(0.7)
                }
                return matchesExpectedPitch ? Color.green.opacity(0.7) : Color.red.opacity(0.7)
            }
            if isPressed { return Color(white: 0.82) }
            if isExpected && !isHighlighted {
                return Color.yellow.opacity(0.35)
            }
            return .white
        }()

        let label = useSolfege ? note.rawValue : note.cde

        return VStack(spacing: 4) {
            Spacer()

            Text(label)
                .font(.system(size: min(keyWidth * 0.35, 13), weight: .bold, design: .rounded))
                .foregroundStyle(isHighlighted ? .white : .gray)

            if octave == 4 && note == .Do {
                Circle()
                    .fill(.orange.opacity(0.6))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.bottom, 8)
        .frame(width: keyWidth, height: keyHeight)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.gray.opacity(0.2), lineWidth: 0.5)
        )
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor.opacity(0.3))
                    .blur(radius: 8)
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture { strike(pitch) }
        .animation(.easeInOut(duration: 0.12), value: isHighlighted)
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isPressed)
    }

    // MARK: - Black Keys

    private func blackKeysOverlay(keyWidth: CGFloat, bkWidth: CGFloat, bkHeight: CGFloat) -> some View {
        HStack(spacing: whiteKeyGap) {
            ForEach(Array(whiteKeys.enumerated()), id: \.offset) { index, key in
                if index < whiteKeys.count - 1 {
                    let solfegeIndex = Solfege.allCases.firstIndex(of: key.0)!
                    if blackKeyIndices.contains(solfegeIndex) {
                        // Sharp = white key's MIDI + 1 semitone (C → C#, D → D#, …)
                        let sharpPitch = Pitch(midi: UInt8(key.0.midiNote(octave: key.1) + 1))
                        blackKeyPlaceholder(pitch: sharpPitch, bkWidth: bkWidth, bkHeight: bkHeight, whiteKeyWidth: keyWidth)
                    } else {
                        Color.clear
                            .frame(width: keyWidth, height: 0)
                    }
                }
            }
        }
        .offset(x: keyWidth * 0.65)
    }

    private func blackKeyPlaceholder(pitch: Pitch, bkWidth: CGFloat, bkHeight: CGFloat, whiteKeyWidth: CGFloat) -> some View {
        let isPressed = pressedKeys.contains(pitch.midi)
        return Rectangle()
            .fill(Color(white: isPressed ? 0.32 : 0.15))
            .frame(width: bkWidth, height: bkHeight)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 3)
            .padding(.horizontal, (whiteKeyWidth - bkWidth) / 2)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .contentShape(Rectangle())
            .onTapGesture { strike(pitch) }
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isPressed)
    }

    /// Fire the audio callback and flash the pressed state for ~180 ms.
    private func strike(_ pitch: Pitch) {
        onKeyTap(pitch)
        pressedKeys.insert(pitch.midi)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            pressedKeys.remove(pitch.midi)
        }
    }
}

#Preview {
    PianoKeyboardView(
        useSolfege: true,
        highlightedNote: .Mi,
        highlightedOctave: 4,
        expectedNote: NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
        isCorrect: true,
        guidedMode: true
    )
    .frame(maxWidth: .infinity)
    .frame(height: 160)
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
