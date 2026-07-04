import SwiftUI
import SwiftData

struct HomeScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Song.sortOrder) private var songs: [Song]
    /// MIDI status injected from `YlapianoApp`. Parents glance at the
    /// toolbar glyph to confirm the keyboard is alive before picking a
    /// song.
    @EnvironmentObject private var midi: MIDIBridge
    /// App-wide sampler — powers the press-a-chip 4-bar preview (B9 stretch).
    @EnvironmentObject private var sampler: PianoSampler
    @State private var showingAddSong = false
    @State private var showingSpike = false
    @State private var hasSeeded = false

    // B9 return-home star-pop: remember the star count the kid last SAW per
    // song (in-memory — a cold launch just baselines, no pop), and mark songs
    // whose stars grew while the home screen was covered by the player.
    @State private var starBaseline: [UUID: Int] = [:]
    @State private var hasStarBaseline = false
    /// songID → star count to animate FROM (the newest stars pop in).
    @State private var starPops: [UUID: Int] = [:]

    // B9 stretch — speaker-chip preview (first 4 bars via PianoSampler).
    @State private var previewingSongID: UUID? = nil
    @State private var previewTask: Task<Void, Never>? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            // #38 (B27) — Pim idles in the header's left slot (per B9's home
            // art system): blink + breathe + occasional tilt, the "this app
            // is alive" signal. Card motion stays B9's star-pop — Pim never
            // competes with the grid.
            HStack(alignment: .bottom) {
                PimIdleView()
                    .frame(width: 116, height: 116)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .accessibilityIdentifier("PimIdleHeader")

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(songs) { song in
                    songCard(song)
                }

                // Add Song card
                Button {
                    showingAddSong = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Palette.ink.opacity(0.25))
                        Text("Add Song")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Palette.ink.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 2, dash: [8])
                            )
                            .foregroundStyle(Palette.ink.opacity(0.18))
                    )
                    .frame(height: 200)
                }
            }
            .padding()
        }
        .background(Palette.cream.ignoresSafeArea())
        .navigationTitle("Ylapiano")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // Same coral-when-connected glyph as PlayerScreen — gives
                // parents a single, consistent connection status indicator.
                Image(systemName: "pianokeys")
                    .font(.system(.title3))
                    .foregroundStyle(midi.isConnected ? Palette.deepRed : .gray)
                    // Explicit Text(...) so both branches localize — a bare
                    // String ternary would resolve to the verbatim overload.
                    .accessibilityLabel(midi.isConnected
                        ? Text("MIDI keyboard connected")
                        : Text("No MIDI keyboard connected"))
            }

            #if DEBUG
            // Sync-spike entry point is a dev tool — never ship in Release.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSpike = true
                } label: {
                    Image(systemName: "testtube.2")
                        .accessibilityLabel("Sync spike")
                }
            }
            #endif
        }
        .navigationDestination(for: Song.self) { song in
            PlayerScreen(song: song)
        }
        .sheet(isPresented: $showingAddSong) {
            AddSongScreen()
        }
        #if DEBUG
        .fullScreenCover(isPresented: $showingSpike) {
            SpikeView()
        }
        #endif
        .onAppear {
            if !hasSeeded {
                SeedData.seedIfNeeded(context: modelContext)
                hasSeeded = true
                #if DEBUG
                applyDebugStarStates()
                #endif
            }
            syncStarBaseline()
        }
        .onDisappear { stopPreview() }
    }

    /// One song card: tap-to-play stays the whole card (NavigationLink); the
    /// preview chip is a SIBLING overlay, not nested inside the link, so the
    /// two gestures can't fight.
    private func songCard(_ song: Song) -> some View {
        ZStack(alignment: .topTrailing) {
            NavigationLink(value: song) {
                SongCardView(
                    song: song,
                    animateFromStars: starPops[song.id],
                    onStarPopFinished: { starPops[song.id] = nil }
                )
                .frame(height: 200)
            }
            .buttonStyle(.plain)

            previewChip(for: song)
                .padding(8)
        }
    }

    // MARK: - Star-pop bookkeeping

    /// On every return to home, diff current bestStars against what the kid
    /// last saw; anything that grew gets a pop marker. First appearance only
    /// baselines (no pop on cold launch).
    private func syncStarBaseline() {
        if hasStarBaseline {
            for song in songs where song.bestStars > (starBaseline[song.id] ?? 0) {
                starPops[song.id] = starBaseline[song.id] ?? 0
            }
        }
        starBaseline = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0.bestStars) })
        hasStarBaseline = true
    }

    // MARK: - B9 stretch: 4-bar preview

    private func previewChip(for song: Song) -> some View {
        let isPreviewing = previewingSongID == song.id
        return Button {
            togglePreview(song)
        } label: {
            Image(systemName: isPreviewing ? "speaker.wave.2.fill" : "speaker.wave.2")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isPreviewing ? Palette.cream : Palette.ink.opacity(0.55))
                .frame(width: 34, height: 34)
                .background(Circle().fill(isPreviewing ? Palette.coral : Palette.ink.opacity(0.07)))
        }
        .accessibilityLabel(isPreviewing
            ? Text("Stop preview")
            : Text("Hear a preview of \(song.displayTitle)"))
    }

    /// Play the first 4 bars (8 beats — catalog songs are felt in 2/4) on the
    /// shared sampler. Pressing another chip stops the current preview;
    /// pressing the same chip toggles it off.
    private func togglePreview(_ song: Song) {
        let wasPreviewing = previewingSongID == song.id
        stopPreview()
        guard !wasPreviewing else { return }

        previewingSongID = song.id
        let notes = song.notes
        let secondsPerBeat = 60.0 / Double(max(song.bpm, 1))
        previewTask = Task { @MainActor in
            defer { if previewingSongID == song.id { previewingSongID = nil } }
            var beats = 0.0
            for note in notes {
                guard beats < 8, !Task.isCancelled else { break }
                if !note.isRest {
                    sampler.play(Pitch(solfege: note.solfege, octave: note.octave), velocity: 90)
                }
                beats += note.duration.beats
                try? await Task.sleep(for: .seconds(note.duration.beats * secondsPerBeat))
            }
        }
    }

    private func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        previewingSongID = nil
    }

    #if DEBUG
    /// Screenshot/dev aid: `-b9-demo-stars` seeds a visible 0/1/2/3 star
    /// spread across the first cards so the star states can be reviewed
    /// without playing, and `-b9-demo-preview` starts the first song's
    /// speaker-chip preview. DEBUG builds only; never ships.
    private func applyDebugStarStates() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-b9-demo-stars") {
            let spread = [3, 1, 2, 0, 2, 1, 3, 0, 1, 2, 3, 1, 2]
            for (index, song) in songs.enumerated() {
                song.bestStars = spread[index % spread.count]
            }
            try? modelContext.save()
        }
        if args.contains("-b9-demo-preview"), let first = songs.first {
            togglePreview(first)
        }
    }
    #endif
}

#Preview {
    NavigationStack {
        HomeScreen()
    }
    .modelContainer(for: Song.self, inMemory: true)
    .environmentObject(MIDIBridge())
    .environmentObject(PianoSampler())
}
