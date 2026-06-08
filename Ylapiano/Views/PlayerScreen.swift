import SwiftUI
import AudioToolbox
import SwiftMIDIIO

struct PlayerScreen: View {
    let song: Song
    @State private var viewModel: PlayerViewModel
    /// Sampler is owned by `YlapianoApp` so its `AVAudioEngine` outlives any
    /// single song screen — we don't want the engine and its session config
    /// to tear down every time the user pops back to `HomeScreen`.
    @EnvironmentObject private var sampler: PianoSampler

    /// MIDI input service injected from `YlapianoApp`. The `.task` modifier
    /// below subscribes to its event stream while this screen is on screen.
    @EnvironmentObject private var midi: MIDIBridge

    /// Which top-panel view the user has chosen: the existing ABC sheet music
    /// (default) or the new Sprint 3 falling-notes lane.
    @State private var displayMode: DisplayMode = .sheetMusic
    private enum DisplayMode { case sheetMusic, fallingNotes }

    /// 3-2-1-Go pre-roll. Non-`nil` means the overlay is on screen; while it
    /// is, the metronome and falling-notes scene stay paused so the kid has
    /// time to put their hand on the first key. Falls back to plain start
    /// when resuming from a pause — the count-in is only for fresh starts.
    @State private var countdownText: String? = nil

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

            // Top panel: either the ABC sheet music or the falling-notes lane.
            // ABCMusicView always renders (it drives the metronome / playback
            // cursor), so when falling-notes mode is on we stack it underneath
            // at zero opacity rather than removing it from the tree.
            if song.notes.isEmpty {
                emptyNotesView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
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
                    .opacity(displayMode == .sheetMusic ? 1 : 0)

                    if displayMode == .fallingNotes {
                        FallingNotesView(
                            song: song,
                            playStartedAt: viewModel.playStartedAt,
                            accumulatedBeforePause: viewModel.accumulatedBeforePause,
                            bpm: viewModel.metronome.bpm
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Current note indicator — only in sheet-music mode. In
            // falling-notes mode it would sit between the scene and the
            // keyboard, breaking the eye's expectation that a falling note
            // lands exactly at the top of its target key (and the yellow
            // key highlight already shows which note is current).
            if displayMode == .sheetMusic {
                currentNoteIndicator
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
            }

            // Piano pinned to bottom
            PianoKeyboardView(
                useSolfege: viewModel.useSolfege,
                highlightedNote: viewModel.pitchDetector.detectedNote,
                highlightedOctave: viewModel.pitchDetector.detectedOctave,
                // Only hint the "expected" key while a song is actively playing;
                // otherwise the yellow glow sits on whatever note the cursor
                // last landed on and looks like a stuck UI bug.
                expectedNote: viewModel.isActive ? viewModel.currentNote : nil,
                isCorrect: viewModel.lastDetectionCorrect,
                guidedMode: viewModel.guidedMode,
                onKeyTap: { pitch in
                    viewModel.handleKeyPressed(pitch, sampler: sampler)
                },
                pressedKeys: viewModel.pressedKeys
            )
            .frame(maxWidth: .infinity)
            .frame(height: 210)
            .padding(.horizontal, 4)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .task {
            // One stream per screen appearance. `.task` cancels the iteration
            // when the view disappears, which terminates this consumer's
            // stream and unregisters it from the bridge's fan-out — so the
            // next screen gets a fresh, working subscription.
            for await event in midi.events() {
                viewModel.handleMIDIEvent(event, sampler: sampler)
            }
        }
        .overlay {
            // Count-in overlay (3 → 2 → 1 → Go) — big rounded numerals
            // layered on top of whichever panel is showing.
            if let text = countdownText {
                ZStack {
                    Color.black.opacity(0.28).ignoresSafeArea()
                    Text(text)
                        .font(.system(size: 220, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                        .transition(.scale(scale: 1.4).combined(with: .opacity))
                        .id(text)
                }
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.68), value: countdownText)
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
        // Mic permission used to be auto-requested here for the legacy
        // listen-and-detect pitch flow. The new tap-to-play + sampler flow
        // doesn't need mic at all, and on Mac Catalyst the permission round
        // trip is unreliable enough to leave the overlay stuck on first run.
        // When we re-introduce a "Listen mode" the request will fire on the
        // toggle, not on view appear.
        .onAppear {
            // Pre-render this song's tones so the first strike of each note
            // doesn't synthesize a buffer inline mid-play (first-touch hitch).
            // Distinct pitches only; tap velocity defaults to 100.
            let pitches = Set(song.notes.map { Pitch(solfege: $0.solfege, octave: $0.octave) })
            sampler.prewarm(Array(pitches))
            viewModel.fallingNotesActive = (displayMode == .fallingNotes)
        }
        .onChange(of: displayMode) { _, newMode in
            // Only judge taps as hits while the falling-notes panel is showing.
            viewModel.fallingNotesActive = (newMode == .fallingNotes)
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
            // Primary button: Play / Pause / Resume.  Fresh starts get a
            // count-in; resumes do not.
            Button {
                if viewModel.isPlaying { viewModel.pausePlaying() }
                else if viewModel.isPaused { viewModel.resumePlaying() }
                else if countdownText == nil { startWithCountdown() }
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

            // MIDI connection indicator — gray when no keyboard is
            // connected, coral when at least one USB MIDI source is alive.
            // No animation per Sprint 2 minimum-viable scope; the full
            // banner + chime + character look-up ships in v1.1.
            Image(systemName: "pianokeys")
                .font(.system(.title3))
                .foregroundStyle(midi.isConnected ? Color(red: 0.84, green: 0.16, blue: 0.16) : .gray)
                .accessibilityLabel(midi.isConnected ? "MIDI keyboard connected" : "No MIDI keyboard connected")
                .frame(width: 36, height: 44)

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

            // Display mode — sheet music vs. falling-notes game lane
            Picker("Display", selection: $displayMode) {
                Image(systemName: "music.note.list").tag(DisplayMode.sheetMusic)
                Image(systemName: "rectangle.stack.fill").tag(DisplayMode.fallingNotes)
            }
            .pickerStyle(.segmented)
            .frame(width: 110)

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

    /// 4-beat count-in at the song's tempo. Plays a system "tock" on each
    /// number so anyone joining on a real keyboard can sync. Tempo-scaled —
    /// at 60 BPM the prep is 4 s, at 120 BPM it's 2 s.
    private func startWithCountdown() {
        let bpm = max(viewModel.metronome.bpm, 30)
        let beatNs = UInt64(60_000_000_000 / bpm)
        countdownText = "3"
        AudioServicesPlaySystemSound(1104)
        Task { @MainActor in
            for n in [2, 1] {
                try? await Task.sleep(nanoseconds: beatNs)
                countdownText = "\(n)"
                AudioServicesPlaySystemSound(1104)
            }
            try? await Task.sleep(nanoseconds: beatNs)
            countdownText = "Go!"
            AudioServicesPlaySystemSound(1104)
            try? await Task.sleep(nanoseconds: beatNs / 2)
            countdownText = nil
            viewModel.startPlaying()
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
                        .font(.custom("NotoMusic-Regular", size: 22))

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
