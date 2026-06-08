import SwiftUI
import SwiftData

@main
struct YlapianoApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Song.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// One `PianoSampler` for the whole app — its `AVAudioEngine` boots once,
    /// configures the shared `AVAudioSession` once, and stays alive across
    /// every navigation. Avoids restart latency and the engine-vs-engine
    /// session race we'd get if each `PlayerScreen` owned its own.
    @StateObject private var sampler = PianoSampler()

    /// App-scoped MIDI input — one `MIDIManager` for the app's lifetime
    /// (CoreMIDI dislikes multiple clients). Auto-connects USB devices on
    /// hot-plug; consumed by `PlayerScreen` and the connection-status glyph.
    @StateObject private var midi = MIDIBridge()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sampler)
                .environmentObject(midi)
        }
        .modelContainer(sharedModelContainer)
    }
}
