import SwiftUI
import SwiftData
import AVKit
import CoreImage
import SwiftMIDIIO

/// Which top panel the player shows. File-scope (not nested) because the
/// grown-ups drawer binds to it too (B10).
enum DisplayMode { case sheetMusic, fallingNotes }

/// Thin shell around one play session. Exists for the B26 next-song handoff:
/// tapping the result screen's handoff card swaps `currentSong`, and the
/// `.id(currentSong.id)` below gives the session a fresh SwiftUI identity —
/// a brand-new `PlayerSessionView` with a brand-new `PlayerViewModel`, no
/// stale hit/rung/result state, without pushing a second screen onto the
/// NavigationStack (the stack has no path binding to pop-and-push with, and
/// stacking players would pile up SpriteKit scenes).
///
/// The landscape orientation lock lives HERE (not on the session) because the
/// shell's identity is stable across song swaps — on the session it would
/// unlock/relock in unspecified onAppear/onDisappear order mid-swap.
struct PlayerScreen: View {
    @State private var currentSong: Song
    /// Set once the kid arrives via the handoff card: the new song starts
    /// itself (count-in included) — one tap total, no second Play press.
    @State private var autoStart = false

    init(song: Song) {
        _currentSong = State(initialValue: song)
    }

    var body: some View {
        // The ZStack is the stable anchor for the orientation lock: its
        // identity never changes, so the lock can't unlock/relock (in
        // unspecified order) when the .id below swaps the session out.
        ZStack {
            PlayerSessionView(song: currentSong, autoStart: autoStart) { next in
                autoStart = true
                currentSong = next
            }
            .id(currentSong.id)
        }
        .onAppear {
            // Gameplay is landscape — the keyboard needs the width. The rest
            // of the app stays free-rotating; we restore that on the way out.
            OrientationGate.lockLandscape()
        }
        .onDisappear { OrientationGate.unlock() }
    }
}

struct PlayerSessionView: View {
    let song: Song
    /// Start the song on arrival (after the usual count-in) — the B26
    /// handoff path. Normal navigation passes false and waits for Play.
    var autoStart = false
    /// The handoff card was tapped: hand the chosen song to the shell.
    var onPlayNext: (Song) -> Void = { _ in }
    @State private var viewModel: PlayerViewModel
    /// Sampler is owned by `YlapianoApp` so its `AVAudioEngine` outlives any
    /// single song screen — we don't want the engine and its session config
    /// to tear down every time the user pops back to `HomeScreen`.
    @EnvironmentObject private var sampler: PianoSampler

    /// MIDI input service injected from `YlapianoApp`. The `.task` modifier
    /// below subscribes to its event stream while this screen is on screen.
    @EnvironmentObject private var midi: MIDIBridge

    /// Which top-panel view is active: the ABC sheet music or the
    /// falling-notes lane.
    // Falling-notes is the front door — the game IS the app, not a hidden tab.
    // Sheet music stays available, but only through the grown-ups drawer (B10).
    @State private var displayMode: DisplayMode = .fallingNotes

    /// B10 — the grown-ups drawer is up. The drawer is an in-screen OVERLAY
    /// panel, deliberately NOT a `.sheet`: adding any sheet modifier beyond
    /// the existing edit sheet (a second `.sheet`, or converting to
    /// `.sheet(item:)` — any variant, any binding host) silently kills
    /// hit-testing of the result overlay's buttons on iOS 18.5 SwiftUI (the
    /// B26 handoff tap went dead; found bisecting #22). Keep this screen at
    /// exactly ONE sheet — the editor — and present everything else as an
    /// overlay.
    @State private var showingGrownUpsDrawer = false

    /// 3-2-1-Go pre-roll. Non-`nil` means the overlay is on screen; while it
    /// is, the metronome and falling-notes scene stay paused so the kid has
    /// time to put their hand on the first key. Falls back to plain start
    /// when resuming from a pause — the count-in is only for fresh starts.
    @State private var countdownText: String? = nil

    /// Gates the heavy top panel (SpriteKit scene / abcjs web view) so the
    /// navigation push renders instantly with a spinner, then builds the panel
    /// one tick later instead of freezing the transition.
    @State private var ready = false

    init(song: Song, autoStart: Bool = false, onPlayNext: @escaping (Song) -> Void = { _ in }) {
        self.song = song
        self.autoStart = autoStart
        self.onPlayNext = onPlayNext
        _viewModel = State(initialValue: PlayerViewModel(song: song))
    }

    /// B26 — who the result screen suggests next. Read from the same store
    /// the home grid shows; nil (no card) only when the song has no context
    /// (previews, fixtures) or no other catalog song exists.
    private var nextSong: Song? {
        guard let context = song.modelContext else { return nil }
        let all = (try? context.fetch(FetchDescriptor<Song>())) ?? []
        return NextSongPicker.next(after: song, in: all)
    }

    var body: some View {
        VStack(spacing: 0) {
            // B10 kid surface: the only controls a kid sees are the big Play
            // (overlaid on the stage below), Pause while playing, the nav-bar
            // back button, and the inert-to-taps grown-up gate. Everything
            // adult-dense (BPM, toggles, pickers, edit, stop) lives in the
            // hold-gated drawer.
            kidTopBar
                .padding(.horizontal, 12)
                .padding(.top, 2)

            // Top panel: either the ABC sheet music or the falling-notes lane.
            // ABCMusicView always renders (it drives the metronome / playback
            // cursor), so when falling-notes mode is on we stack it underneath
            // at zero opacity rather than removing it from the tree.
            if song.notes.isEmpty {
                emptyNotesView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !ready {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    // abcjs is a WKWebView (heavy to spin up), so only build it in
                    // sheet-music mode. Falling-notes mode drives the beat and the
                    // end-of-song off the SpriteKit scene's own clock, so abcjs
                    // isn't needed there — which is what kept the song screen from
                    // opening instantly.
                    if displayMode == .sheetMusic {
                        ABCMusicView(
                            abcNotation: song.notes.toABC(title: song.title, timeSignature: "2/4", useSolfege: viewModel.useSolfege, bpm: viewModel.metronome.bpm),
                            isPlaying: viewModel.isPlaying,
                            isPaused: viewModel.isPaused,
                            bpm: viewModel.metronome.bpm,
                            playNotes: viewModel.playNotes,
                            playMetronome: viewModel.playMetronome,
                            onNoteChange: { index in
                                viewModel.currentNoteIndex = viewModel.entryIndex(forSoundingIndex: index)
                            },
                            // B10 (PR #33 residual): sheet playback no longer
                            // ends in silence — a no-stars toast + soft ding
                            // acknowledge the run (stars stay game-only).
                            onPlaybackEnd: { viewModel.finishSheetPlayback() }
                        )
                    } else {
                        FallingNotesView(
                            song: song,
                            playStartedAt: viewModel.playStartedAt,
                            accumulatedBeforePause: viewModel.accumulatedBeforePause,
                            bpm: viewModel.metronome.bpm,
                            lastHit: viewModel.lastHit,
                            beatsEnabled: viewModel.playMetronome,
                            onBeat: { sampler.playTock() },
                            onSongEnd: { viewModel.finishSong() }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // B10 — the ONE big obvious control. Icon, not text; center
                // stage; starts (with count-in) or resumes. Hidden while
                // playing so nothing covers the falling notes.
                .overlay {
                    if !viewModel.isPlaying, countdownText == nil, !viewModel.songFinished {
                        bigPlayButton
                    }
                }
                // B10 sheet-run acknowledgement toast (no stars — see
                // finishSheetPlayback). Auto-dismisses after a beat.
                .overlay(alignment: .bottom) {
                    if viewModel.sheetRunEnded {
                        sheetRunToast
                            .padding(.bottom, 18)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.sheetRunEnded)
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
                // Falling-notes mode now glows the target key off the SAME clock
                // as the bars (`guidanceNote`, sampled from `elapsedSeconds` +
                // lead-in) — the synced rung-1/2 guidance the ladder calls for.
                // Rung 3 dims it (`guidanceOpacity`), rung 4 turns it off
                // (`guidanceNote` stays nil). Sheet-music mode keeps the abcjs
                // cursor's `currentNote` glow as before.
                expectedNote: displayMode == .fallingNotes
                    ? viewModel.guidanceNote
                    : (viewModel.isActive ? viewModel.currentNote : nil),
                guidedMode: viewModel.guidedMode,
                guidanceOpacity: viewModel.currentRung.guidance.glowOpacity ?? 0.35,
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
        .navigationTitle(song.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Build the heavy panel one tick after the push so the transition
            // never freezes; spinner shows until then.
            guard !ready else { return }
            try? await Task.sleep(for: .milliseconds(50))
            ready = true
            // B26 handoff: arriving via the next-song card starts the song
            // itself — with the same count-in a Play press gets, so the kid
            // still has time to find the first key.
            if autoStart, !song.notes.isEmpty {
                try? await Task.sleep(for: .milliseconds(350))
                if countdownText == nil, !viewModel.isActive { startWithCountdown() }
            }
        }
        .onAppear {
            viewModel.fallingNotesActive = (displayMode == .fallingNotes)
            #if DEBUG
            fireDemoResultIfRequested()
            #endif
            // Pre-render this song's tones AFTER the transition settles, so the
            // synth work can't block the push. An un-cached note still
            // synthesizes inline on first tap.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(150))
                let pitches = Set(song.notes.filter { !$0.isRest }
                    .map { Pitch(solfege: $0.solfege, octave: $0.octave) })
                sampler.prewarm(Array(pitches))
            }
        }
        .onChange(of: displayMode) { _, newMode in
            // Only judge taps as hits while the falling-notes panel is showing.
            viewModel.fallingNotesActive = (newMode == .fallingNotes)
        }
        .onDisappear {
            viewModel.stopPlaying()
        }
        // The screen's ONE and only sheet — the song editor, exactly as it
        // shipped pre-B10. See `showingGrownUpsDrawer`'s doc comment: any
        // additional sheet modifier here breaks the result overlay's taps.
        .sheet(isPresented: $viewModel.showingEditSheet) {
            AddSongScreen(existingSong: song)
        }
        .overlay {
            // End-of-song result — the squirrel mascot + earned stars, and (on
            // a clean 3-star run) the climb-a-rung offer. Celebrate + replay,
            // nothing a 5yo has to read. (Near-miss report cut — Defne: it's an
            // adult deliberate-practice model; parked to the upper rungs.)
            if viewModel.songFinished {
                SongResultView(
                    stars: viewModel.resultStars,
                    rungName: viewModel.resultRungName,
                    canClimb: viewModel.canClimb,
                    climbLabel: viewModel.climbLabel,
                    climbIsLightsOff: viewModel.climbIsLightsOff,
                    nextSong: nextSong,
                    onReplay: { viewModel.replaySong() },
                    onClimb: { viewModel.climbRung() },
                    onPlayNext: onPlayNext
                )
            }
        }
        // B10 — the grown-ups drawer, an overlay panel (NOT a sheet; see
        // `showingGrownUpsDrawer`). Above the result overlay: an adult opened
        // it deliberately, it wins.
        .overlay {
            if showingGrownUpsDrawer {
                GrownUpsDrawerView(
                    viewModel: viewModel,
                    displayMode: $displayMode,
                    midiConnected: midi.isConnected,
                    onEditSong: {
                        showingGrownUpsDrawer = false
                        viewModel.showingEditSheet = true
                    },
                    onClose: { showingGrownUpsDrawer = false }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.85), value: showingGrownUpsDrawer)
    }

    #if DEBUG
    /// UI-test / screenshot aid: `-b26-demo-result-stars N` finishes the first
    /// opened song with N stars shortly after it appears, so the result screen
    /// (and the handoff card) can be exercised without playing a full song.
    /// Fires once per launch — the handed-off song must NOT instantly
    /// re-finish. DEBUG only; never ships.
    @MainActor private static var demoResultFired = false
    private func fireDemoResultIfRequested() {
        let stars = UserDefaults.standard.integer(forKey: "b26-demo-result-stars")
        guard stars > 0, !Self.demoResultFired else { return }
        Self.demoResultFired = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            viewModel.setResult(stars: min(stars, 3))
        }
    }
    #endif

    // MARK: - Kid surface (B10)

    /// The slim strip a kid sees above the stage: Pause while playing (the
    /// one in-play control — it can't break anything), and the grown-up gate
    /// (inert to taps; a 2.5 s hold opens the drawer). Nothing else.
    private var kidTopBar: some View {
        HStack(spacing: 14) {
            if viewModel.isPlaying {
                Button {
                    viewModel.pausePlaying()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(.title3, weight: .bold))
                        .frame(width: 56, height: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .accessibilityLabel("Pause")
            }

            Spacer()

            GrownUpGateButton { showingGrownUpsDrawer = true }
        }
        .frame(height: 48)
    }

    /// The ONE big kid control: a 150 pt icon-only circle, center stage.
    /// Fresh start runs the count-in; a pause resumes without one.
    private var bigPlayButton: some View {
        Button {
            if viewModel.isPaused { viewModel.resumePlaying() }
            else if countdownText == nil { startWithCountdown() }
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 64, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 150, height: 150)
                .background(Circle().fill(Palette.leafGreen))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        // Explicit Text(...) so both branches localize (B13).
        .accessibilityLabel(viewModel.isPaused ? Text("Resume") : Text("Play"))
        .accessibilityIdentifier("BigPlayButton")
    }

    /// B10 sheet-run acknowledgement — the run gets a moment, not stars
    /// (stars require judged play). Plays a soft ding on appear and clears
    /// itself after a beat.
    private var sheetRunToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "music.note")
            Text("Nice practicing!")
                .font(.system(.title3, design: .rounded, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Capsule().fill(Palette.coral))
        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
        .task {
            sampler.playStarDing(2)
            try? await Task.sleep(for: .seconds(2.5))
            viewModel.acknowledgeSheetRun()
        }
    }

    /// 4-beat (`CountIn.beats`) count-in at the song's tempo, so anyone
    /// joining on a real keyboard can sync. Tempo-scaled — at 60 BPM the prep
    /// is 4 s, at 120 BPM it's 2 s.
    ///
    /// The four tocks are scheduled up front on the shared `AVAudioEngine`'s
    /// render clock (`sampler.playCountIn`) — sample-accurate spacing, media
    /// volume, same silent-switch behavior as the piano (B6 #14). The overlay
    /// numerals below follow on `Task.sleep`, which only has to be close
    /// enough for eyes, not ears.
    private func startWithCountdown() {
        let bpm = max(viewModel.metronome.bpm, 30)
        let beatNs = UInt64(60_000_000_000 / bpm)
        sampler.playCountIn(bpm: bpm)
        countdownText = "3"
        Task { @MainActor in
            for n in [2, 1] {
                try? await Task.sleep(nanoseconds: beatNs)
                countdownText = "\(n)"
            }
            try? await Task.sleep(nanoseconds: beatNs)
            countdownText = String(localized: "Go!")
            try? await Task.sleep(nanoseconds: beatNs / 2)
            countdownText = nil
            viewModel.startPlaying()
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
                Text("No notes yet — ask a grown-up to add some.")
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
            // B10 sub-task 4: the note editor is grown-up territory — even
            // from the empty state, the only way in is a deliberate hold.
            GrownUpGateButton(label: "Hold to add notes") {
                viewModel.showingEditSheet = true
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

// MARK: - Grown-ups drawer (B10 #22)

/// Everything the old adult-dense toolbar held, now behind the hold gate:
/// tempo, sound toggles, notation, display mode, MIDI status, edit, stop.
/// A kid never sees this; a parent holds the gate 2.5 s to open it.
///
/// Presented as an in-screen OVERLAY panel, deliberately not a `.sheet` —
/// see `showingGrownUpsDrawer` in `PlayerSessionView` for the iOS 18.5 bug
/// a second sheet triggers.
private struct GrownUpsDrawerView: View {
    @Bindable var viewModel: PlayerViewModel
    @Binding var displayMode: DisplayMode
    let midiConnected: Bool
    let onEditSong: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            // Dim scrim; tapping outside the panel closes the drawer.
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Grown-ups")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                    Spacer()
                    Button("Done") { onClose() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                Divider()

                ScrollView {
                    VStack(spacing: 4) {
                        row("BPM") {
                            HStack(spacing: 4) {
                                Button {
                                    viewModel.setBPM(viewModel.metronome.bpm - 5)
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(.body, weight: .bold))
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.blue)

                                Menu {
                                    ForEach([45, 60, 75, 90, 120, 150], id: \.self) { preset in
                                        Button {
                                            viewModel.setBPM(preset)
                                        } label: {
                                            if viewModel.metronome.bpm == preset {
                                                Label("\(preset) BPM", systemImage: "checkmark")
                                            } else {
                                                Text("\(preset) BPM")
                                            }
                                        }
                                    }
                                } label: {
                                    Text("\(viewModel.metronome.bpm)")
                                        .font(.system(.title3, design: .rounded, weight: .bold))
                                        .monospacedDigit()
                                        .frame(width: 60, height: 44)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    viewModel.setBPM(viewModel.metronome.bpm + 5)
                                } label: {
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
                        }

                        Divider()

                        Toggle("Play Piano", isOn: $viewModel.playNotes)
                            .padding(.horizontal, 20)
                            .frame(height: 52)
                        Toggle("Metronome", isOn: $viewModel.playMetronome)
                            .padding(.horizontal, 20)
                            .frame(height: 52)

                        Divider()

                        row("Notation") {
                            Picker("Notation", selection: $viewModel.useSolfege) {
                                Text("Do Re Mi").tag(true)
                                Text("C D E").tag(false)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }
                        row("View") {
                            Picker("View", selection: $displayMode) {
                                Text("Falling notes").tag(DisplayMode.fallingNotes)
                                Text("Sheet music").tag(DisplayMode.sheetMusic)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 240)
                        }

                        Divider()

                        Button {
                            onEditSong()
                        } label: {
                            HStack {
                                Label("Edit Song", systemImage: "pencil")
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .frame(height: 52)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)

                        row("MIDI Keyboard") {
                            Text(midiConnected ? "Connected" : "Not connected")
                                .foregroundStyle(midiConnected ? Palette.deepRed : .secondary)
                        }

                        if viewModel.isActive {
                            Divider()
                            Button(role: .destructive) {
                                viewModel.stopPlaying()
                                onClose()
                            } label: {
                                HStack {
                                    Label("Stop Song", systemImage: "stop.fill")
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .frame(height: 52)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .font(.system(.body, design: .rounded))
            .frame(maxWidth: 520, maxHeight: 640)
            .background(RoundedRectangle(cornerRadius: 22).fill(Color(uiColor: .systemBackground)))
            .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
            .padding(32)
            .accessibilityIdentifier("GrownUpsDrawer")
        }
    }

    /// One label-left, control-right row. LocalizedStringKey so the literal
    /// labels resolve through the String Catalog (B13).
    private func row<Content: View>(_ label: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
            Spacer()
            content()
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 52)
    }
}

/// End-of-song result — a celebration, not a static card. The squirrel reacts,
/// the earned stars pop in ONE AT A TIME, and a perfect 3/3 fires a sparkle
/// burst + a mascot wiggle. The mascot pose swaps per result: chibi-canon
/// "MascotCheer" for 3 stars, "MascotGreeting" otherwise (B7 still pack).
/// Stars never drop below 1; never a frown. Honors Reduce Motion.
private struct SongResultView: View {
    let stars: Int
    /// The rung just played, e.g. "Find the beat" — names where the player is
    /// on the ladder without numbers a 5yo can't read.
    let rungName: String?
    /// A clean 3-star run with a rung above → offer the climb. The headline CTA
    /// becomes "Faster!" / "Lights off!"; replay stays available beside it.
    let canClimb: Bool
    /// Already-localized climb CTA text (the view model owns the wording).
    let climbLabel: String
    /// Semantic flavor of the climb — drives the icon. A flag, not a string
    /// compare against the label, which localization would break (B13).
    let climbIsLightsOff: Bool
    /// B26 — the song the handoff card offers. nil = no card (no other
    /// catalog song, or a context-less preview).
    let nextSong: Song?
    let onReplay: () -> Void
    let onClimb: () -> Void
    let onPlayNext: (Song) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// B11 — star dings + tier fanfare play through the shared engine.
    @EnvironmentObject private var sampler: PianoSampler

    @State private var card = false        // card + mascot enter
    @State private var revealed = 0        // earned stars shown so far
    @State private var celebrate = false   // 3/3 sparkle burst
    @State private var burst: CGFloat = 0  // 0→1 drives the burst outward
    @State private var wiggle = false      // mascot reaction on a perfect run
    @State private var handoff = false     // B26 next-song card springs in last

    private let gold = Palette.gold
    private let coral = Palette.coral
    private var perfect: Bool { stars >= 3 }


    /// B11 — one random draw per presentation from the tier's celebration
    /// pool (`PimReactionPool`; "hmm" never plays on a completion). `@State`'s
    /// initial value is computed once per view identity, so the clip stays
    /// put across re-renders instead of reshuffling on every state change.
    @State private var rewardClip = Int.random(in: 0..<Int.max)

    /// Per-tier reward clip — Pim reacts to how the kid did, drawn from the
    /// tier's variety pool (1★ = clap only, warm; 2★/3★ = clap or jump-cheer).
    /// `nil` if the clip is missing, so the still fallback below keeps working.
    private var tierVideoURL: URL? {
        let pool = PimReactionPool.clips(forStars: stars)
        return Bundle.main.url(forResource: pool[rewardClip % pool.count], withExtension: "mp4")
    }

    /// Still fallback when Reduce Motion is on or a reward clip is missing.
    /// 3/3 shows the cheer pose; other tiers the greeting wave.
    private var mascotImage: UIImage {
        UIImage(named: perfect ? "MascotCheer" : "MascotGreeting") ?? UIImage()
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    if celebrate {
                        ForEach(0..<10, id: \.self) { i in
                            let angle = Double(i) / 10 * 2 * .pi
                            Image(systemName: "sparkle")
                                .font(.system(size: 20))
                                .foregroundStyle(gold)
                                .offset(x: cos(angle) * 95 * burst, y: sin(angle) * 95 * burst)
                                .opacity(Double(1 - burst))
                                .scaleEffect(0.3 + burst)
                        }
                    }
                    Group {
                        // Reward clip when bundled + motion allowed; the white-bg
                        // video sits in a cream rounded "stage" so its edges blend
                        // into the app's cream palette instead of reading as a box.
                        if let url = tierVideoURL, !reduceMotion {
                            // White background is chroma-keyed out in the player,
                            // so Pim floats transparently on the card.
                            LoopingVideoView(url: url)
                                .frame(width: 170, height: 170)
                        } else {
                            Image(uiImage: mascotImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 170, height: 170)
                        }
                    }
                    .scaleEffect(card ? (celebrate ? 1.08 : 1) : 0.4)
                    .rotationEffect(.degrees(wiggle ? 5 : (card ? 0 : -8)))
                }

                if let rungName {
                    // localizedUppercase: Turkish dotted/dotless i uppercases
                    // wrong under the locale-insensitive uppercased() (B13).
                    Text(rungName.localizedUppercase)
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.18)))
                        .opacity(card ? 1 : 0)
                }

                HStack(spacing: 18) {
                    ForEach(0..<3, id: \.self) { index in
                        let earned = index < stars
                        let shown = index < revealed
                        Image(systemName: earned ? "star.fill" : "star")
                            .font(.system(size: 56))
                            .foregroundStyle(earned ? gold : Color.white.opacity(0.35))
                            .scaleEffect(earned ? (shown ? 1 : 0.1) : 1)
                            .opacity(earned ? (shown ? 1 : 0) : 0.6)
                            .rotationEffect(.degrees(earned && !shown ? -40 : 0))
                    }
                }

                // B26 hero placement: no climb on offer → the handoff card IS
                // the headline CTA, straight under the stars. (When the climb
                // is offered it keeps the headline and the card sits below —
                // climbing is opt-in per the rung design; don't fight its CTA.)
                if let nextSong, !canClimb {
                    handoffCard(nextSong, hero: true)
                }

                // Action row. On a clean 3-star run the headline becomes the
                // climb ("Faster!" / "Lights off!"); replay is always there too,
                // but visually secondary whenever a bigger invitation (climb or
                // handoff card) is on screen — kids can also replay from home.
                HStack(spacing: 20) {
                    Button(action: onReplay) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 76, height: 76)
                            .background(Circle().fill(canClimb || nextSong != nil ? Color.white.opacity(0.22) : coral))
                            .shadow(radius: 8, y: 4)
                    }
                    .accessibilityLabel("Play again")

                    if canClimb {
                        Button(action: onClimb) {
                            HStack(spacing: 10) {
                                Image(systemName: climbIsLightsOff ? "lightbulb.slash.fill" : "hare.fill")
                                Text(climbLabel)
                                    .font(.system(.title3, design: .rounded, weight: .heavy))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 26)
                            .frame(height: 76)
                            .background(Capsule().fill(coral))
                            .shadow(radius: 8, y: 4)
                        }
                        .accessibilityLabel(climbLabel)
                        .scaleEffect(celebrate ? 1.04 : 1)
                    }
                }
                .scaleEffect(card ? 1 : 0.5)

                // B26 secondary placement: the climb owns the headline, the
                // handoff card waits quietly below it.
                if let nextSong, canClimb {
                    handoffCard(nextSong, hero: false)
                }
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial))
            .padding(40)
            .scaleEffect(card ? 1 : 0.85)
        }
        .task { await runSequence() }
    }

    /// B26 — the next-song invitation: Pim points at ONE oversized picture
    /// card (the next song's B9 icon, small title, its current stars — no
    /// pressure copy, the card itself is the invitation). One tap starts that
    /// song. Springs in with a Back.Out-style overshoot (~350 ms) after the
    /// star sequence; static appear under Reduce Motion (`runSequence` just
    /// sets `handoff` without animation).
    ///
    /// The interactive card is only MOUNTED once `handoff` flips — before the
    /// spring it must not exist at all. The earlier always-mounted version
    /// (scaleEffect/opacity driven by `handoff`, later patched with
    /// `allowsHitTesting` + `accessibilityHidden`) left a full-frame,
    /// zero-opacity button in the tree during the multi-second star sequence:
    /// an accessibility query found it (XCUITest's element tree ignores
    /// `accessibilityHidden` on an identified button here), computed hit
    /// point {-1, -1} on the invisible view, and the tap landed nowhere —
    /// the deterministic NextSongHandoffUITests failure in #57. A `hidden()`
    /// ghost keeps the layout slot from the first frame so the result card
    /// never resizes when the card springs in.
    private func handoffCard(_ next: Song, hero: Bool) -> some View {
        ZStack {
            handoffCardContent(next, hero: hero)
                .hidden()
            if handoff {
                handoffCardContent(next, hero: hero)
                    .transition(.scale(scale: 0.25).combined(with: .opacity))
            }
        }
    }

    private func handoffCardContent(_ next: Song, hero: Bool) -> some View {
        HStack(alignment: .bottom, spacing: 4) {
            // Pim points to the right — the card sits where he points.
            Image("MascotPointing")
                .resizable()
                .scaledToFit()
                .frame(width: hero ? 104 : 68, height: hero ? 104 : 68)
                .accessibilityHidden(true)

            Button { onPlayNext(next) } label: {
                SongCardView(song: next)
                    .frame(width: hero ? 180 : 128, height: hero ? 196 : 140)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play \(next.displayTitle) next")
            .accessibilityIdentifier("NextSongHandoffCard")
        }
    }

    @MainActor
    private func runSequence() async {
        let beat = ResultSoundDesign.starBeatMilliseconds
        guard !reduceMotion else {
            card = true
            revealed = stars
            celebrate = perfect
            burst = 0           // no motion burst in reduced mode
            handoff = true      // static appear — no spring under Reduce Motion
            // Sound is not motion (B11): the celebration still PLAYS under
            // Reduce Motion — rising dings on the star beat, then the fanfare.
            for i in 0..<max(stars, 1) {
                sampler.playStarDing(i)
                try? await Task.sleep(for: .milliseconds(beat))
            }
            sampler.playResultFanfare(stars: stars)
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { card = true }
        try? await Task.sleep(for: .milliseconds(320))
        // Reveal earned stars one at a time — pop, beat, pop, beat. Each pop
        // lands with its ding — one warm piano note, rising Do–Mi–Sol (B11).
        for i in 1...max(stars, 1) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { revealed = i }
            sampler.playStarDing(i - 1)
            try? await Task.sleep(for: .milliseconds(beat))
        }
        // Tier fanfare, one beat after the last star: 1★ warm, 2★ brighter,
        // 3★ full flourish (random variation) under the sparkle burst.
        sampler.playResultFanfare(stars: stars)
        if perfect {
            // Perfect run: sparkle burst + a happy wiggle.
            celebrate = true
            withAnimation(.easeOut(duration: 0.7)) { burst = 1 }
            withAnimation(.easeInOut(duration: 0.12).repeatCount(6, autoreverses: true)) { wiggle = true }
        }
        // The handoff moment: one beat after the last star (or the burst)
        // lands, the next-song card springs in — Back.Out overshoot, ~350 ms.
        try? await Task.sleep(for: .milliseconds(perfect ? 650 : 380))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { handoff = true }
    }
}

/// Plays a bundled clip on a seamless loop, muted, scaled to fit (so Pim is
/// never stretched). Used for the per-tier reward video in `SongResultView`.
/// Muted because the reward sound is a separate, layered SFX (Khalid's lane),
/// not the clip's own audio. Honors Reduce Motion at the call site (the view is
/// only mounted when motion is allowed).
private struct LoopingVideoView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> LoopingPlayerUIView { LoopingPlayerUIView(url: url) }
    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}
}

/// Weak target for the render `CADisplayLink`. The link retains its target, so
/// pointing it straight at the view would keep the view (and its player +
/// CIContext + frame buffers) alive forever — `deinit`, which invalidates the
/// link, could never fire. The proxy holds the view weakly to break that cycle.
private final class DisplayLinkProxy: NSObject {
    weak var view: LoopingPlayerUIView?
    init(_ view: LoopingPlayerUIView) { self.view = view }
    @objc func tick() { view?.renderFrame() }
}

private final class LoopingPlayerUIView: UIView {
    private let player = AVPlayer()
    private let output = AVPlayerItemVideoOutput(
        pixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
    )
    private let ciContext = CIContext()
    private let keyFilter: CIFilter?
    private var displayLink: CADisplayLink?
    private var endObserver: NSObjectProtocol?

    init(url: URL) {
        // Build the chroma-key filter up front; if CIColorCube is somehow
        // unavailable we simply skip keying (video still plays) rather than crash.
        let filter = CIFilter(name: "CIColorCube")
        filter?.setValue(32, forKey: "inputCubeDimension")
        filter?.setValue(Self.greenKeyCubeData(dimension: 32), forKey: "inputCubeData")
        self.keyFilter = filter

        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        layer.contentsGravity = .resizeAspect      // never stretch Pim

        // We render frames ourselves to `layer.contents` because AVPlayerLayer
        // composites video over an opaque background and drops the alpha our
        // chroma-key produces. A plain CALayer honors per-pixel alpha.
        let item = AVPlayerItem(url: url)
        item.add(output)
        player.replaceCurrentItem(with: item)
        player.isMuted = true
        player.actionAtItemEnd = .none

        // Seamless loop without AVPlayerLooper (which swaps items and would
        // detach our video output).
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }

        // Weak proxy so the link doesn't retain us (see DisplayLinkProxy). The
        // clip is a pre-rendered loop, so ~30fps is plenty and halves the
        // per-frame Core Image cost.
        let link = CADisplayLink(target: DisplayLinkProxy(self), selector: #selector(DisplayLinkProxy.tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
        player.play()
    }

    @objc fileprivate func renderFrame() {
        guard let item = player.currentItem else { return }
        let time = item.currentTime()
        guard output.hasNewPixelBuffer(forItemTime: time),
              let buffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil)
        else { return }

        var image = CIImage(cvPixelBuffer: buffer)
        if let keyFilter {
            keyFilter.setValue(image, forKey: kCIInputImageKey)
            image = keyFilter.outputImage ?? image
        }
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return }
        layer.contents = cgImage
    }

    /// Premultiplied RGBA color cube: keys out the chroma-green backdrop (green
    /// clearly dominant over red+blue) to transparent, feathered at the edge,
    /// plus a light despill that trims leftover green tint on kept pixels. Pim
    /// is orange/cream — green never dominates there — so he stays fully opaque
    /// while the flat green screen is removed cleanly.
    private static func greenKeyCubeData(dimension dim: Int) -> Data {
        func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
            let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
            return t * t * (3 - 2 * t)
        }
        var cube = [Float]()
        cube.reserveCapacity(dim * dim * dim * 4)
        let n = Float(dim - 1)
        for b in 0..<dim {
            for g in 0..<dim {
                for r in 0..<dim {
                    let rf = Float(r) / n, gf = Float(g) / n, bf = Float(b) / n
                    let other = max(rf, bf)
                    let greenness = gf - other          // how much green exceeds red/blue
                    var alpha: Float = 1
                    // Anything clearly green-dominant keys FULLY (alpha 0) by
                    // greenness 0.12 — feather only 0.04→0.12 — so a slightly
                    // washed-out green backdrop (e.g. the jump clip, greenness
                    // ~0.18) doesn't land mid-feather and leave a green haze.
                    if gf > 0.28 && greenness > 0.04 {  // green-dominant → backdrop
                        alpha = 1 - smoothstep(0.04, 0.12, greenness)
                    }
                    // Despill: pull excess green down so kept edges don't tint green.
                    let og = greenness > 0 ? other + greenness * 0.4 : gf
                    cube.append(rf * alpha)             // premultiplied
                    cube.append(og * alpha)
                    cube.append(bf * alpha)
                    cube.append(alpha)
                }
            }
        }
        return cube.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    deinit {
        displayLink?.invalidate()
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
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
