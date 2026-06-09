import SwiftUI
import AudioToolbox
import AVKit
import CoreImage
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
    // Falling-notes is the front door — the game IS the app, not a hidden tab.
    // Sheet music stays available via the toolbar toggle.
    @State private var displayMode: DisplayMode = .fallingNotes
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
                        // In the falling-notes game the kid plays the melody and
                        // the scene drives the beat (one clock, synced to the
                        // blocks). Keep abcjs silent here so a second timebase
                        // can't drift against the blocks — it still runs as the
                        // timing cursor / end detector.
                        playNotes: displayMode == .fallingNotes ? false : viewModel.playNotes,
                        playMetronome: displayMode == .fallingNotes ? false : viewModel.playMetronome,
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
                            bpm: viewModel.metronome.bpm,
                            lastHit: viewModel.lastHit,
                            beatsEnabled: viewModel.playMetronome,
                            onSongEnd: { viewModel.finishSong() }
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
                // Falling-notes mode now glows the target key off the SAME clock
                // as the bars (`guidanceNote`, sampled from `elapsedSeconds` +
                // lead-in) — the synced rung-1/2 guidance the ladder calls for.
                // Rung 3 dims it (`guidanceOpacity`), rung 4 turns it off
                // (`guidanceNote` stays nil). Sheet-music mode keeps the abcjs
                // cursor's `currentNote` glow as before.
                expectedNote: displayMode == .fallingNotes
                    ? viewModel.guidanceNote
                    : (viewModel.isActive ? viewModel.currentNote : nil),
                isCorrect: viewModel.lastDetectionCorrect,
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
            // Gameplay is landscape — the keyboard needs the width. The rest of
            // the app stays free-rotating; we restore that on the way out.
            OrientationGate.lockLandscape()
        }
        .onChange(of: displayMode) { _, newMode in
            // Only judge taps as hits while the falling-notes panel is showing.
            viewModel.fallingNotesActive = (newMode == .fallingNotes)
        }
        .onDisappear {
            viewModel.stopPlaying()
            OrientationGate.unlock()   // back to free rotation outside gameplay
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
        .overlay {
            // End-of-song result — the squirrel mascot + earned stars, and (on
            // a clean 3-star run) the climb-a-rung offer. Celebrate + replay,
            // nothing a 5yo has to read. (Near-miss report cut — Defne: it's an
            // adult deliberate-practice model; parked to the upper rungs.)
            if viewModel.songFinished {
                SongResultView(
                    stars: viewModel.resultStars,
                    rungName: viewModel.currentRung.name,
                    canClimb: viewModel.canClimb,
                    climbLabel: viewModel.climbLabel,
                    onReplay: { viewModel.replaySong() },
                    onClimb: { viewModel.climbRung() }
                )
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

/// End-of-song result — a celebration, not a static card. The squirrel reacts,
/// the earned stars pop in ONE AT A TIME, and a perfect 3/3 fires a sparkle
/// burst + a mascot wiggle. The mascot pose swaps per result: drop an
/// OpenArt-generated **"MascotCheer"** (thumbs-up / high-five squirrel) into
/// Assets and it shows for 3 stars — falls back to the normal "Mascot" until
/// then. Stars never drop below 1; never a frown. Honors Reduce Motion.
private struct SongResultView: View {
    let stars: Int
    /// The rung just played, e.g. "Find the beat" — names where the player is
    /// on the ladder without numbers a 5yo can't read.
    let rungName: String
    /// A clean 3-star run with a rung above → offer the climb. The headline CTA
    /// becomes "Faster!" / "Lights off!"; replay stays available beside it.
    let canClimb: Bool
    let climbLabel: String
    let onReplay: () -> Void
    let onClimb: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var card = false        // card + mascot enter
    @State private var revealed = 0        // earned stars shown so far
    @State private var celebrate = false   // 3/3 sparkle burst
    @State private var burst: CGFloat = 0  // 0→1 drives the burst outward
    @State private var wiggle = false      // mascot reaction on a perfect run

    private let gold = Color(red: 1.0, green: 0.78, blue: 0.20)
    private let coral = Color(red: 0.97, green: 0.45, blue: 0.30)
    private var perfect: Bool { stars >= 3 }

    private let cream = Color(red: 1.0, green: 0.97, blue: 0.93)

    /// Per-tier reward clip — Pim reacts to how the kid did (1★ = "hmm, again!",
    /// 2★ = clap, 3★ = jump-cheer). Looks up `PimResult1/2/3.mp4` in the bundle;
    /// `nil` until that asset is added, so the still fallback below keeps working.
    private var tierVideoURL: URL? {
        Bundle.main.url(forResource: "PimResult\(min(max(stars, 1), 3))", withExtension: "mp4")
    }

    /// Still fallback (reduced motion, or before the clips are bundled). 3/3
    /// swaps to a cheer pose if that asset exists; otherwise the default squirrel.
    private var mascotImage: UIImage {
        let name = perfect ? "MascotCheer" : "Mascot"
        return UIImage(named: name) ?? UIImage(named: "Mascot") ?? UIImage()
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

                Text(rungName.uppercased())
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.18)))
                    .opacity(card ? 1 : 0)

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

                // Action row. On a clean 3-star run the headline becomes the
                // climb ("Faster!" / "Lights off!"); replay is always there too.
                HStack(spacing: 20) {
                    Button(action: onReplay) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 76, height: 76)
                            .background(Circle().fill(canClimb ? Color.white.opacity(0.22) : coral))
                            .shadow(radius: 8, y: 4)
                    }
                    .accessibilityLabel("Play again")

                    if canClimb {
                        Button(action: onClimb) {
                            HStack(spacing: 10) {
                                Image(systemName: climbLabel == "Lights off!" ? "lightbulb.slash.fill" : "hare.fill")
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
            }
            .padding(40)
            .background(RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial))
            .padding(40)
            .scaleEffect(card ? 1 : 0.85)
        }
        .task { await runSequence() }
    }

    @MainActor
    private func runSequence() async {
        guard !reduceMotion else {
            card = true
            revealed = stars
            celebrate = perfect
            burst = 0           // no motion burst in reduced mode
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { card = true }
        try? await Task.sleep(for: .milliseconds(320))
        // Reveal earned stars one at a time — pop, beat, pop, beat.
        for i in 1...max(stars, 1) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) { revealed = i }
            try? await Task.sleep(for: .milliseconds(340))
        }
        guard perfect else { return }
        // Perfect run: sparkle burst + a happy wiggle.
        celebrate = true
        withAnimation(.easeOut(duration: 0.7)) { burst = 1 }
        withAnimation(.easeInOut(duration: 0.12).repeatCount(6, autoreverses: true)) { wiggle = true }
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

private final class LoopingPlayerUIView: UIView {
    private let queuePlayer = AVQueuePlayer()
    private var looper: AVPlayerLooper?

    override class var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    init(url: URL) {
        super.init(frame: .zero)
        isOpaque = false               // let the keyed-out background show the card through
        backgroundColor = .clear

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.videoComposition = Self.chromaKeyComposition(for: asset)

        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        queuePlayer.isMuted = true
        playerLayer.player = queuePlayer
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = UIColor.clear.cgColor
        queuePlayer.play()
    }

    /// Per-frame composition that keys the near-white background to transparent
    /// via a `CIColorCube` — Pim's saturated fur survives, the flat white drops out.
    private static func chromaKeyComposition(for asset: AVAsset) -> AVVideoComposition {
        let dimension = 32
        let filter = CIFilter(name: "CIColorCube")!
        filter.setValue(dimension, forKey: "inputCubeDimension")
        filter.setValue(whiteKeyCubeData(dimension: dimension), forKey: "inputCubeData")
        let context = CIContext()
        return AVMutableVideoComposition(asset: asset) { request in
            filter.setValue(request.sourceImage.clampedToExtent(), forKey: kCIInputImageKey)
            let output = (filter.outputImage ?? request.sourceImage)
                .cropped(to: request.sourceImage.extent)
            request.finish(with: output, context: context)
        }
    }

    /// Builds a premultiplied RGBA color cube: desaturated near-white → alpha 0
    /// (feathered), everything else opaque. Saturation gate protects Pim's cream
    /// belly and eye-shine from being punched out with the flat-white backdrop.
    private static func whiteKeyCubeData(dimension dim: Int) -> Data {
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
                    let lo = min(rf, min(gf, bf)), hi = max(rf, max(gf, bf))
                    var alpha: Float = 1
                    if (hi - lo) < 0.13 {                 // desaturated → candidate background
                        alpha = 1 - smoothstep(0.78, 0.90, lo)
                    }
                    cube.append(rf * alpha)               // premultiplied
                    cube.append(gf * alpha)
                    cube.append(bf * alpha)
                    cube.append(alpha)
                }
            }
        }
        return cube.withUnsafeBufferPointer { Data(buffer: $0) }
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
