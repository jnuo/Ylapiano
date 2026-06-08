import SwiftUI
import SwiftData

struct HomeScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Song.sortOrder) private var songs: [Song]
    /// MIDI status injected from `YlapianoApp`. Parents glance at the
    /// toolbar glyph to confirm the keyboard is alive before picking a
    /// song.
    @EnvironmentObject private var midi: MIDIBridge
    @State private var showingAddSong = false
    @State private var showingSpike = false
    @State private var hasSeeded = false

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    NavigationLink(value: song) {
                        SongCardView(
                            song: song,
                            color: SongCardView.color(for: index)
                        )
                        .frame(height: 200)
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(song)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                // Add Song card
                Button {
                    showingAddSong = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.gray.opacity(0.5))
                        Text("Add Song")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                style: StrokeStyle(lineWidth: 2, dash: [8])
                            )
                            .foregroundStyle(.gray.opacity(0.3))
                    )
                    .frame(height: 200)
                }
            }
            .padding()
        }
        .navigationTitle("Ylapiano")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                // Same coral-when-connected glyph as PlayerScreen — gives
                // parents a single, consistent connection status indicator.
                Image(systemName: "pianokeys")
                    .font(.system(.title3))
                    .foregroundStyle(midi.isConnected ? Color(red: 0.84, green: 0.16, blue: 0.16) : .gray)
                    .accessibilityLabel(midi.isConnected ? "MIDI keyboard connected" : "No MIDI keyboard connected")
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
            }
        }
    }
}

#Preview {
    NavigationStack {
        HomeScreen()
    }
    .modelContainer(for: Song.self, inMemory: true)
}
