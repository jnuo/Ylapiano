import SwiftUI

struct PianoKeyboardView: View {
    let useSolfege: Bool
    let highlightedNote: Solfege?
    let highlightedOctave: Int?
    let expectedNote: NoteEntry?
    let isCorrect: Bool?
    let guidedMode: Bool

    // 3 octaves: C3-B5
    private let startOctave = 3
    private let octaveCount = 3
    private let whiteKeyWidth: CGFloat = 44
    private let whiteKeyHeight: CGFloat = 180
    private let blackKeyWidth: CGFloat = 28
    private let blackKeyHeight: CGFloat = 110

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

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                // White keys
                HStack(spacing: 1) {
                    ForEach(Array(whiteKeys.enumerated()), id: \.offset) { index, key in
                        whiteKeyView(note: key.0, octave: key.1)
                    }
                }

                // Black keys
                blackKeysOverlay
            }
        }
    }

    // MARK: - White Key

    private func whiteKeyView(note: Solfege, octave: Int) -> some View {
        let isHighlighted = highlightedNote == note && highlightedOctave == octave
        let isExpected = guidedMode && expectedNote?.solfege == note && expectedNote?.octave == octave
        let matchesExpectedPitch = highlightedNote == note // Match regardless of octave for young learners

        let backgroundColor: Color = {
            if isHighlighted {
                if let isCorrect {
                    return isCorrect ? Color.green.opacity(0.7) : Color.red.opacity(0.7)
                }
                return matchesExpectedPitch ? Color.green.opacity(0.7) : Color.red.opacity(0.7)
            }
            if isExpected && !isHighlighted {
                return Color.yellow.opacity(0.35)
            }
            return .white
        }()

        let label = useSolfege ? note.rawValue : note.cde

        return VStack(spacing: 4) {
            Spacer()

            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isHighlighted ? .white : .gray)

            if octave == 4 && note == .Do {
                Circle()
                    .fill(.orange.opacity(0.6))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.bottom, 8)
        .frame(width: whiteKeyWidth, height: whiteKeyHeight)
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
        .animation(.easeInOut(duration: 0.15), value: isHighlighted)
    }

    // MARK: - Black Keys

    private var blackKeysOverlay: some View {
        HStack(spacing: 1) {
            ForEach(Array(whiteKeys.enumerated()), id: \.offset) { index, key in
                if index < whiteKeys.count - 1 {
                    let solfegeIndex = Solfege.allCases.firstIndex(of: key.0)!
                    if blackKeyIndices.contains(solfegeIndex) {
                        blackKeyPlaceholder
                    } else {
                        Color.clear
                            .frame(width: whiteKeyWidth, height: 0)
                    }
                }
            }
        }
        .offset(x: whiteKeyWidth * 0.65)
    }

    private var blackKeyPlaceholder: some View {
        Rectangle()
            .fill(Color(white: 0.15))
            .frame(width: blackKeyWidth, height: blackKeyHeight)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 3)
            .padding(.horizontal, (whiteKeyWidth - blackKeyWidth) / 2)
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
    .frame(height: 200)
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
