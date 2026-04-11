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
                    abcNotation: song.notes.toABC(title: song.title, timeSignature: "2/4", useSolfege: viewModel.useSolfege),
                    highlightIndex: viewModel.currentNoteIndex,
                    isPlaying: viewModel.isPlaying,
                    bpm: song.bpm,
                    onNoteChange: { index in
                        viewModel.currentNoteIndex = index
                    },
                    onPlaybackEnd: {
                        viewModel.stopPlaying()
                    },
                    onBeat: {
                        // Metronome tick handled by JS timing
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
        HStack(spacing: 8) {
            // Play/Stop
            Button {
                if viewModel.isPlaying { viewModel.stopPlaying() }
                else { viewModel.startPlaying() }
            } label: {
                Image(systemName: viewModel.isPlaying ? "stop.fill" : "play.fill")
                    .font(.body)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isPlaying ? .red : .green)

            // BPM inline
            Button { if viewModel.metronome.bpm > 40 { viewModel.metronome.bpm -= 5 } } label: {
                Image(systemName: "minus.circle").font(.body).foregroundStyle(.blue)
            }.buttonStyle(.plain)

            Text("\(viewModel.metronome.bpm)")
                .font(.system(.body, design: .rounded, weight: .bold))
                .monospacedDigit()

            Button { if viewModel.metronome.bpm < 220 { viewModel.metronome.bpm += 5 } } label: {
                Image(systemName: "plus.circle").font(.body).foregroundStyle(.blue)
            }.buttonStyle(.plain)

            // Edit
            Button { viewModel.showingEditSheet = true } label: {
                Image(systemName: "pencil.circle").font(.body).foregroundStyle(.blue)
            }.buttonStyle(.plain)

            Spacer()

            // Notation toggle
            Toggle(isOn: Binding(
                get: { viewModel.useSolfege },
                set: { _ in viewModel.toggleNotation() }
            )) {
                Text(viewModel.useSolfege ? "Do Re Mi" : "C D E")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
            }
            .toggleStyle(.switch)
            .fixedSize()

            // Guided
            Button { viewModel.toggleGuided() } label: {
                Image(systemName: viewModel.guidedMode ? "hand.point.right.fill" : "hand.point.right")
                    .font(.caption)
                    .padding(6)
                    .background(Capsule().fill(viewModel.guidedMode ? .yellow.opacity(0.25) : .gray.opacity(0.15)))
            }.buttonStyle(.plain)

            // Mic dot
            Circle()
                .fill(viewModel.pitchDetector.isListening ? .green : .gray)
                .frame(width: 8, height: 8)
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
