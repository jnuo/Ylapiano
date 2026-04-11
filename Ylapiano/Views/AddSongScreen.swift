import SwiftUI
import SwiftData

struct AddSongScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var bpm = 100
    @State private var notes: [NoteEntry] = []
    @State private var quickInputText = ""

    // For editing an existing song
    var existingSong: Song?

    init(existingSong: Song? = nil) {
        self.existingSong = existingSong
        if let song = existingSong {
            _title = State(initialValue: song.title)
            _bpm = State(initialValue: song.bpm)
            _notes = State(initialValue: song.notes)
        }
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && bpm > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Song info section
                Section {
                    TextField("Song Title", text: $title)
                        .font(.system(.body, design: .rounded))

                    HStack {
                        Text("BPM")
                            .font(.system(.body, design: .rounded))
                        Spacer()
                        HStack(spacing: 12) {
                            Button {
                                if bpm > 40 { bpm -= 5 }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)

                            Text("\(bpm)")
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .frame(width: 50)

                            Button {
                                if bpm < 220 { bpm += 5 }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Label("Song Info", systemImage: "music.note")
                }

                // Quick input section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type notes separated by spaces:")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)

                        TextField("Do Do Sol Sol La La Sol", text: $quickInputText)
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        HStack {
                            Button("Add as Quarter Notes") {
                                addQuickNotes(duration: .quarter)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            .disabled(quickInputText.trimmingCharacters(in: .whitespaces).isEmpty)

                            Button("Add as Eighth Notes") {
                                addQuickNotes(duration: .eighth)
                            }
                            .buttonStyle(.bordered)
                            .disabled(quickInputText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .font(.system(.caption, design: .rounded))
                    }
                } header: {
                    Label("Quick Input", systemImage: "keyboard")
                }

                // Notes list section
                Section {
                    if notes.isEmpty {
                        Text("No notes added yet. Use Quick Input above or tap + below.")
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(Array(notes.enumerated()), id: \.element.id) { index, _ in
                            NoteEntryRow(
                                note: $notes[index],
                                index: index,
                                onDelete: { notes.remove(at: index) }
                            )
                        }
                        .onMove { from, to in
                            notes.move(fromOffsets: from, toOffset: to)
                        }
                    }

                    Button {
                        notes.append(
                            NoteEntry(solfege: .Do, octave: 4, duration: .quarter)
                        )
                    } label: {
                        Label("Add Note", systemImage: "plus.circle")
                            .font(.system(.body, design: .rounded))
                    }
                } header: {
                    Label("Notes (\(notes.count))", systemImage: "music.note.list")
                }
            }
            .navigationTitle(existingSong != nil ? "Edit Song" : "New Song")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(!isValid)
                    .font(.system(.body, design: .rounded, weight: .bold))
                }
            }
        }
    }

    private func addQuickNotes(duration: NoteDuration) {
        let tokens = quickInputText
            .trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        for token in tokens {
            if let solfege = Solfege.allCases.first(where: {
                $0.rawValue.lowercased() == token.lowercased()
            }) {
                notes.append(NoteEntry(solfege: solfege, octave: 4, duration: duration))
            }
        }
        quickInputText = ""
    }

    private func save() {
        if let existingSong {
            existingSong.title = title
            existingSong.bpm = bpm
            existingSong.notes = notes
        } else {
            let song = Song(title: title, bpm: bpm, notes: notes)
            modelContext.insert(song)
        }
        try? modelContext.save()
    }
}

#Preview {
    AddSongScreen()
        .modelContainer(for: Song.self, inMemory: true)
}
