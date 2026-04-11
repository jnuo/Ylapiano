import SwiftUI

struct SheetMusicView: View {
    let notes: [NoteEntry]
    let currentNoteIndex: Int
    let useSolfege: Bool

    private let staffLineSpacing: CGFloat = 12
    private let noteSpacing: CGFloat = 70
    private let noteRadius: CGFloat = 10
    private let staffTopPadding: CGFloat = 60
    private let ledgerLineWidth: CGFloat = 28

    // Staff lines represent E4, G4, B4, D5, F5 (bottom to top)
    // Middle C (Do4) is one ledger line below the staff
    // Staff position 0 = C4 (middle C), each +1 = one diatonic step up

    private func yPosition(for staffPos: Int) -> CGFloat {
        // Staff line positions (bottom to top): E4=2, G4=4, B4=6, D5=8, F5=10
        // The bottom line (E4, staffPos=2) is at y = staffTopPadding + 4 * staffLineSpacing
        // Each staff position step moves half a staffLineSpacing
        let bottomLineY = staffTopPadding + 4 * staffLineSpacing
        let e4Position = 2 // E4 staff position
        return bottomLineY - CGFloat(staffPos - e4Position) * (staffLineSpacing / 2.0)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // Draw staff lines
                    staffLines

                    // Draw notes
                    ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                        noteView(note: note, index: index)
                            .id(index)
                    }

                    // Treble clef
                    Text("𝄞")
                        .font(.system(size: 52))
                        .foregroundStyle(.primary.opacity(0.6))
                        .offset(x: 8, y: staffTopPadding - 8)
                }
                .frame(
                    width: max(CGFloat(notes.count) * noteSpacing + 120, 400),
                    height: staffTopPadding + 6 * staffLineSpacing
                )
                .padding(.horizontal, 20)
            }
            .onChange(of: currentNoteIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    // MARK: - Staff Lines

    private var staffLines: some View {
        Canvas { context, size in
            let startX: CGFloat = 0
            let endX = size.width

            for i in 0..<5 {
                let y = staffTopPadding + CGFloat(i) * staffLineSpacing
                var path = Path()
                path.move(to: CGPoint(x: startX, y: y))
                path.addLine(to: CGPoint(x: endX, y: y))
                context.stroke(path, with: .color(.primary.opacity(0.3)), lineWidth: 1)
            }
        }
    }

    // MARK: - Note View

    private func noteView(note: NoteEntry, index: Int) -> some View {
        let staffPos = note.solfege.staffPosition(octave: note.octave)
        let x = CGFloat(index) * noteSpacing + 80
        let y = yPosition(for: staffPos)
        let isActive = index == currentNoteIndex
        let isPast = index < currentNoteIndex

        return ZStack {
            // Ledger lines if needed
            ledgerLines(staffPos: staffPos, x: x)

            // Note head
            noteHead(note: note, isActive: isActive, isPast: isPast)

            // Stem for quarter, half, eighth
            if note.duration != .whole {
                noteStem(y: y, staffPos: staffPos, isActive: isActive, isPast: isPast)
            }

            // Flag for eighth notes
            if note.duration == .eighth {
                eighthFlag(staffPos: staffPos, isActive: isActive, isPast: isPast)
            }

            // Note label
            noteLabel(note: note, isActive: isActive)
        }
        .offset(x: x, y: y)
    }

    private func noteHead(note: NoteEntry, isActive: Bool, isPast: Bool) -> some View {
        let filled = note.duration == .quarter || note.duration == .eighth

        return Ellipse()
            .fill(isActive ? Color.orange : (isPast ? Color.gray.opacity(0.4) : Color.primary))
            .frame(width: noteRadius * 2.2, height: noteRadius * 1.7)
            .overlay(
                Ellipse()
                    .strokeBorder(
                        isActive ? Color.orange : (isPast ? Color.gray.opacity(0.4) : Color.primary),
                        lineWidth: filled ? 0 : 2
                    )
            )
            .overlay(
                Group {
                    if !filled {
                        Ellipse()
                            .fill(Color(uiColor: .systemBackground))
                            .frame(width: noteRadius * 1.4, height: noteRadius * 0.8)
                    }
                }
            )
            .scaleEffect(isActive ? 1.3 : 1.0)
            .animation(.spring(response: 0.3), value: isActive)
    }

    private func noteStem(y: CGFloat, staffPos: Int, isActive: Bool, isPast: Bool) -> some View {
        let stemUp = staffPos < 6 // Below B4, stem goes up
        let stemHeight: CGFloat = staffLineSpacing * 3.5

        return Rectangle()
            .fill(isActive ? Color.orange : (isPast ? Color.gray.opacity(0.4) : Color.primary))
            .frame(width: 1.5, height: stemHeight)
            .offset(
                x: stemUp ? noteRadius * 1.0 : -noteRadius * 1.0,
                y: stemUp ? -stemHeight / 2 : stemHeight / 2
            )
    }

    private func eighthFlag(staffPos: Int, isActive: Bool, isPast: Bool) -> some View {
        let stemUp = staffPos < 6
        let flagColor = isActive ? Color.orange : (isPast ? Color.gray.opacity(0.4) : Color.primary)

        return Text(stemUp ? "⚑" : "⚑")
            .font(.system(size: 14))
            .foregroundStyle(flagColor)
            .opacity(0) // Using stem only for eighth, beam not rendered individually
    }

    private func ledgerLines(staffPos: Int, x: CGFloat) -> some View {
        Canvas { context, _ in
            // Ledger lines below staff (C4 = position 0, D4 = 1)
            if staffPos <= 0 {
                // Draw ledger line for C4 (middle C) and below
                var pos = 0
                while pos >= staffPos {
                    if pos % 2 == 0 { // Only on line positions
                        let y = yPosition(for: pos)
                        var path = Path()
                        path.move(to: CGPoint(x: -ledgerLineWidth / 2, y: y))
                        path.addLine(to: CGPoint(x: ledgerLineWidth / 2, y: y))
                        context.stroke(path, with: .color(.primary.opacity(0.3)), lineWidth: 1)
                    }
                    pos -= 1
                }
            }

            // Ledger lines above staff (A5 = position 12 and above)
            if staffPos >= 12 {
                var pos = 12
                while pos <= staffPos {
                    if pos % 2 == 0 {
                        let y = yPosition(for: pos)
                        var path = Path()
                        path.move(to: CGPoint(x: -ledgerLineWidth / 2, y: y))
                        path.addLine(to: CGPoint(x: ledgerLineWidth / 2, y: y))
                        context.stroke(path, with: .color(.primary.opacity(0.3)), lineWidth: 1)
                    }
                    pos += 1
                }
            }
        }
        .frame(width: ledgerLineWidth, height: 1)
    }

    private func noteLabel(note: NoteEntry, isActive: Bool) -> some View {
        let label = useSolfege ? note.solfege.rawValue : note.solfege.cde

        return Text(label)
            .font(.system(size: isActive ? 13 : 10, weight: .bold, design: .rounded))
            .foregroundStyle(isActive ? .orange : .secondary)
            .offset(y: 20)
    }
}

#Preview {
    SheetMusicView(
        notes: [
            NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
            NoteEntry(solfege: .Re, octave: 4, duration: .quarter),
            NoteEntry(solfege: .Mi, octave: 4, duration: .half),
            NoteEntry(solfege: .Fa, octave: 4, duration: .quarter),
            NoteEntry(solfege: .Sol, octave: 4, duration: .whole),
            NoteEntry(solfege: .La, octave: 4, duration: .eighth),
            NoteEntry(solfege: .Si, octave: 4, duration: .quarter),
            NoteEntry(solfege: .Do, octave: 5, duration: .half),
        ],
        currentNoteIndex: 2,
        useSolfege: true
    )
    .frame(height: 200)
    .padding()
}
