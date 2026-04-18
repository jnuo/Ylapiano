import SwiftUI
import SwiftData

struct HomeScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Song.sortOrder) private var songs: [Song]
    @State private var showingAddSong = false
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
        .navigationDestination(for: Song.self) { song in
            PlayerScreen(song: song)
        }
        .sheet(isPresented: $showingAddSong) {
            AddSongScreen()
        }
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
