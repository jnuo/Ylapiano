import SwiftUI

struct NoteEntryRow: View {
    @Binding var note: NoteEntry
    let index: Int
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Index badge
            Text("\(index + 1)")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(.blue.opacity(0.7)))

            // Solfège picker
            Picker("Note", selection: $note.solfege) {
                ForEach(Solfege.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)

            // Octave stepper
            HStack(spacing: 4) {
                Text("Oct")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                Stepper("\(note.octave)", value: $note.octave, in: 3...6)
                    .labelsHidden()
                Text("\(note.octave)")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .frame(width: 20)
            }

            // Duration picker
            Picker("Duration", selection: $note.duration) {
                ForEach(NoteDuration.allCases) { d in
                    Text(d.displayName).tag(d)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)

            Spacer()

            // Delete button
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    @Previewable @State var note = NoteEntry(solfege: .Do, octave: 4, duration: .quarter)
    NoteEntryRow(note: $note, index: 0, onDelete: {})
        .padding()
}
