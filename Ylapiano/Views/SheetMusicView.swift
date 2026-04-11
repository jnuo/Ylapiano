import SwiftUI

struct SheetMusicView: View {
    let notes: [NoteEntry]
    let currentNoteIndex: Int
    let useSolfege: Bool

    // Layout constants
    private let lineSpacing: CGFloat = 10
    private let noteRadius: CGFloat = 7
    private let notesPerLine = 8
    private let clefWidth: CGFloat = 40

    // Staff height = 4 gaps between 5 lines
    private var staffHeight: CGFloat { 4 * lineSpacing }
    // Each line row: stem room + staff + label room
    private var rowHeight: CGFloat { staffHeight + 70 }

    // Staff position: C4=0, D4=1, E4=2, F4=3, G4=4, A4=5, B4=6, C5=7...
    // Staff lines (bottom to top): E4=2, G4=4, B4=6, D5=8, F5=10
    private func yOnStaff(for staffPos: Int) -> CGFloat {
        let bottomLineY = staffHeight // E4 line is at bottom of staff
        let e4Position = 2
        return bottomLineY - CGFloat(staffPos - e4Position) * (lineSpacing / 2.0)
    }

    private var lines: [[Int]] {
        var result: [[Int]] = []
        var i = 0
        while i < notes.count {
            let end = min(i + notesPerLine, notes.count)
            result.append(Array(i..<end))
            i = end
        }
        return result
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { lineIdx, noteIndices in
                        staffRow(noteIndices: noteIndices, lineIdx: lineIdx)
                            .frame(height: rowHeight)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: currentNoteIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    // MARK: - Staff Row

    private func staffRow(noteIndices: [Int], lineIdx: Int) -> some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width - clefWidth
            let spacing = availableWidth / CGFloat(notesPerLine)
            let staffTop: CGFloat = 28 // room for upward stems

            ZStack(alignment: .topLeading) {
                // 5 staff lines
                ForEach(0..<5, id: \.self) { i in
                    let y = staffTop + CGFloat(i) * lineSpacing
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.primary.opacity(0.25), lineWidth: 1)
                }

                // Treble clef on first line
                if lineIdx == 0 {
                    Text("𝄞")
                        .font(.system(size: 36))
                        .foregroundStyle(.primary.opacity(0.5))
                        .offset(x: 2, y: staffTop - 6)
                }

                // Notes
                ForEach(noteIndices, id: \.self) { idx in
                    let note = notes[idx]
                    let posInLine = idx - noteIndices.first!
                    let x = clefWidth + CGFloat(posInLine) * spacing + spacing / 2
                    let staffPos = note.solfege.staffPosition(octave: note.octave)
                    let y = staffTop + yOnStaff(for: staffPos)
                    let isActive = idx == currentNoteIndex
                    let isPast = idx < currentNoteIndex
                    let filled = note.duration == .quarter || note.duration == .eighth
                    let color = isActive ? Color.orange : (isPast ? Color.gray.opacity(0.4) : Color.primary)

                    // Ledger lines
                    if staffPos <= 0 {
                        ForEach(stride(from: 0, through: staffPos, by: -2).map { $0 }, id: \.self) { pos in
                            let ly = staffTop + yOnStaff(for: pos)
                            Path { path in
                                path.move(to: CGPoint(x: x - 12, y: ly))
                                path.addLine(to: CGPoint(x: x + 12, y: ly))
                            }
                            .stroke(Color.primary.opacity(0.25), lineWidth: 1)
                        }
                    }

                    // Note head
                    Ellipse()
                        .fill(color)
                        .frame(width: noteRadius * 2.2, height: noteRadius * 1.6)
                        .overlay(
                            Group {
                                if !filled {
                                    Ellipse()
                                        .fill(Color(uiColor: .systemBackground))
                                        .frame(width: noteRadius * 1.2, height: noteRadius * 0.6)
                                }
                            }
                        )
                        .scaleEffect(isActive ? 1.25 : 1.0)
                        .position(x: x, y: y)
                        .id(idx)

                    // Stem
                    if note.duration != .whole {
                        let stemUp = staffPos < 6
                        let stemH: CGFloat = lineSpacing * 3
                        Rectangle()
                            .fill(color)
                            .frame(width: 1.5, height: stemH)
                            .position(
                                x: x + (stemUp ? noteRadius : -noteRadius),
                                y: stemUp ? y - stemH / 2 : y + stemH / 2
                            )
                    }

                    // Note label below staff
                    Text(useSolfege ? note.solfege.rawValue : note.solfege.cde)
                        .font(.system(size: isActive ? 11 : 9, weight: .bold, design: .rounded))
                        .foregroundStyle(isActive ? .orange : .secondary)
                        .position(x: x, y: staffTop + staffHeight + 18)
                }
            }
        }
    }
}

#Preview {
    SheetMusicView(
        notes: [
            NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
            NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
            NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
            NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
            NoteEntry(solfege: .La, octave: 4, duration: .quarter),
            NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
            NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
            NoteEntry(solfege: .La, octave: 4, duration: .quarter),
            NoteEntry(solfege: .Sol, octave: 4, duration: .half),
            NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
            NoteEntry(solfege: .Mi, octave: 4, duration: .quarter),
            NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
            NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
        ],
        currentNoteIndex: 3,
        useSolfege: true
    )
    .frame(height: 300)
    .padding()
}
