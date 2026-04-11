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
            // Top: Metronome bar
            MetronomeBarView(
                metronome: viewModel.metronome,
                onEditSong: { viewModel.showingEditSheet = true }
            )
            .padding(.horizontal)
            .padding(.top, 8)

            // Toolbar row
            toolbarRow
                .padding(.horizontal)
                .padding(.vertical, 6)

            // Main content: sheet music (left) + piano (right)
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // Left panel: Sheet Music
                    VStack(spacing: 0) {
                        if song.notes.isEmpty {
                            emptyNotesView
                        } else {
                            SheetMusicView(
                                notes: song.notes,
                                currentNoteIndex: viewModel.currentNoteIndex,
                                useSolfege: viewModel.useSolfege
                            )
                        }
                    }
                    .frame(width: geo.size.width * 0.55)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(uiColor: .systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 4)
                    )
                    .padding(.leading, 8)

                    // Right panel: Piano Keyboard
                    VStack(spacing: 8) {
                        // Current note indicator
                        currentNoteIndicator
                            .padding(.horizontal)

                        PianoKeyboardView(
                            useSolfege: viewModel.useSolfege,
                            highlightedNote: viewModel.pitchDetector.detectedNote,
                            highlightedOctave: viewModel.pitchDetector.detectedOctave,
                            expectedNote: viewModel.currentNote,
                            isCorrect: viewModel.lastDetectionCorrect,
                            guidedMode: viewModel.guidedMode
                        )
                    }
                    .frame(width: geo.size.width * 0.45)
                    .padding(.trailing, 8)
                }
            }
            .padding(.bottom, 8)

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
        HStack(spacing: 16) {
            // Play controls
            if !song.notes.isEmpty {
                Button {
                    if viewModel.isPlaying {
                        viewModel.stopPlaying()
                    } else {
                        viewModel.startPlaying()
                    }
                } label: {
                    Label(
                        viewModel.isPlaying ? "Stop" : "Start",
                        systemImage: viewModel.isPlaying ? "stop.fill" : "play.fill"
                    )
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isPlaying ? .red : .green)

                if viewModel.isPlaying || viewModel.currentNoteIndex > 0 {
                    Button {
                        viewModel.restart()
                    } label: {
                        Label("Restart", systemImage: "arrow.counterclockwise")
                            .font(.system(.subheadline, design: .rounded))
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer()

            // Notation toggle
            Button {
                viewModel.toggleNotation()
            } label: {
                Text(viewModel.useSolfege ? "Do Re Mi" : "C D E")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(.blue.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)

            // Guided mode toggle
            Button {
                viewModel.toggleGuided()
            } label: {
                Label(
                    viewModel.guidedMode ? "Guided" : "Free",
                    systemImage: viewModel.guidedMode ? "hand.point.right.fill" : "hand.point.right"
                )
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        viewModel.guidedMode ? .yellow.opacity(0.25) : .gray.opacity(0.15)
                    )
                )
            }
            .buttonStyle(.plain)

            // Mic status
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.pitchDetector.isListening ? .green : .gray)
                    .frame(width: 8, height: 8)
                Image(systemName: "mic.fill")
                    .font(.caption)
                    .foregroundStyle(viewModel.pitchDetector.isListening ? .green : .gray)
            }
        }
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
