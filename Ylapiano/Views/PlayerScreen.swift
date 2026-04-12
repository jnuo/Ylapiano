import SwiftUI

struct PlayerScreen: View {
    let song: Song
    @State private var viewModel: PlayerViewModel

    init(song: Song) {
        self.song = song
        _viewModel = State(initialValue: PlayerViewModel(song: song))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Single compact toolbar row
            toolbarRow
                .padding(.horizontal, 12)
                .padding(.top, 2)

            // Sheet music fills all remaining space
            if song.notes.isEmpty {
                emptyNotesView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ABCMusicView(
                    abcNotation: song.notes.toABC(title: song.title, timeSignature: "2/4", useSolfege: viewModel.useSolfege, bpm: viewModel.metronome.bpm),
                    isPlaying: viewModel.isPlaying,
                    isPaused: viewModel.isPaused,
                    bpm: viewModel.metronome.bpm,
                    playNotes: viewModel.playNotes,
                    playMetronome: viewModel.playMetronome,
                    onNoteChange: { index in
                        viewModel.currentNoteIndex = index
                    },
                    onPlaybackEnd: {
                        viewModel.stopPlaying()
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Current note indicator
            currentNoteIndicator
                .padding(.horizontal, 16)
                .padding(.vertical, 2)

            // Piano pinned to bottom
            PianoKeyboardView(
                useSolfege: viewModel.useSolfege,
                highlightedNote: viewModel.pitchDetector.detectedNote,
                highlightedOctave: viewModel.pitchDetector.detectedOctave,
                expectedNote: viewModel.currentNote,
                isCorrect: viewModel.lastDetectionCorrect,
                guidedMode: viewModel.guidedMode
            )
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .padding(.horizontal, 4)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .overlay {
            // Feedback overlay
            if let flash = viewModel.feedbackFlash {
                Rectangle()
                    .fill(flash.opacity(0.15))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .navigationTitle(song.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.requestMicPermission()
        }
        .onDisappear {
            viewModel.stopPlaying()
        }
        .onChange(of: viewModel.pitchDetector.detectedNote) { _, _ in
            viewModel.checkDetectedNote()
        }
        .sheet(isPresented: $viewModel.showingEditSheet) {
            AddSongScreen(existingSong: song)
        }
        .overlay {
            // Completion overlay
            if viewModel.isComplete && viewModel.currentNoteIndex > 0 {
                completionOverlay
            }
        }
        .overlay {
            // Mic permission prompt
            if viewModel.pitchDetector.permissionDenied {
                micPermissionOverlay
            }
        }
    }

    // MARK: - Toolbar Row

    private var toolbarRow: some View {
        HStack(spacing: 14) {
            // Primary button: Play / Pause / Resume
            Button {
                if viewModel.isPlaying { viewModel.pausePlaying() }
                else if viewModel.isPaused { viewModel.resumePlaying() }
                else { viewModel.startPlaying() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    Text(viewModel.isPlaying ? "Pause" : (viewModel.isPaused ? "Resume" : "Play"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .frame(minWidth: 90, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isPlaying ? .orange : .green)

            // Stop button: only when active
            if viewModel.isActive {
                Button {
                    viewModel.stopPlaying()
                } label: {
                    Image(systemName: "stop.fill")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            // BPM stepper — clear label, big tap targets
            HStack(spacing: 4) {
                Button { if viewModel.metronome.bpm > 40 { viewModel.metronome.bpm -= 5 } } label: {
                    Image(systemName: "minus")
                        .font(.system(.body, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Menu {
                    ForEach([45, 60, 75, 90, 120, 150], id: \.self) { preset in
                        Button {
                            viewModel.metronome.bpm = preset
                        } label: {
                            if viewModel.metronome.bpm == preset {
                                Label("\(preset) BPM", systemImage: "checkmark")
                            } else {
                                Text("\(preset) BPM")
                            }
                        }
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text("\(viewModel.metronome.bpm)")
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text("BPM")
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 50, height: 44)
                }
                .buttonStyle(.plain)

                Button { if viewModel.metronome.bpm < 220 { viewModel.metronome.bpm += 5 } } label: {
                    Image(systemName: "plus")
                        .font(.system(.body, weight: .bold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .tertiarySystemFill))
            )

            Spacer()

            // Sound toggles — labeled pill buttons with obvious on/off state
            soundToggle(
                label: "Play Piano",
                icon: "speaker.wave.2.fill",
                iconOff: "speaker.slash.fill",
                isOn: viewModel.playNotes,
                color: .blue
            ) { viewModel.playNotes.toggle() }

            soundToggle(
                label: "Metronome",
                icon: "metronome.fill",
                iconOff: "metronome",
                isOn: viewModel.playMetronome,
                color: .orange
            ) { viewModel.playMetronome.toggle() }

            // Notation format — compact segmented
            Picker("Notation", selection: Binding(
                get: { viewModel.useSolfege },
                set: { _ in viewModel.toggleNotation() }
            )) {
                Text("Do Re Mi").tag(true)
                Text("C D E").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 160)

            // Edit — subtle, last
            Button { viewModel.showingEditSheet = true } label: {
                Image(systemName: "pencil")
                    .font(.system(.body, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }

    private func soundToggle(
        label: String,
        icon: String,
        iconOff: String,
        isOn: Bool,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isOn ? icon : iconOff)
                    .font(.body)
                Text(label)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .foregroundStyle(isOn ? .white : color)
            .background(
                Capsule()
                    .fill(isOn ? color : color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Current Note Indicator

    private var currentNoteIndicator: some View {
        Group {
            if let note = viewModel.currentNote {
                HStack(spacing: 8) {
                    Text("Play:")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text(viewModel.useSolfege ? note.solfege.rawValue : note.solfege.cde)
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(.orange)

                    Text(note.duration.symbol)
                        .font(.title2)

                    Spacer()

                    Text("\(viewModel.currentNoteIndex + 1)/\(song.notes.count)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                )
            } else if song.notes.isEmpty {
                Text("No notes — tap edit to add some!")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Empty State

    private var emptyNotesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No notes yet")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
            Button("Add Notes") {
                viewModel.showingEditSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Completion Overlay

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce, options: .repeating)

                Text("Great job!")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                Text("You played all the notes!")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))

                HStack(spacing: 16) {
                    Button {
                        viewModel.restart()
                    } label: {
                        Label("Play Again", systemImage: "arrow.counterclockwise")
                            .font(.system(.headline, design: .rounded))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    // MARK: - Mic Permission

    private var micPermissionOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)

            Text("Microphone Access Needed")
                .font(.system(.headline, design: .rounded))

            Text("Go to Settings > Ylapiano to enable microphone access.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
        .padding()
    }
}

#Preview {
    NavigationStack {
        PlayerScreen(song: Song(
            title: "Plim Plim",
            bpm: 90,
            notes: [
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .quarter),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .La, octave: 4, duration: .quarter),
                NoteEntry(solfege: .Sol, octave: 4, duration: .half),
            ]
        ))
    }
}
