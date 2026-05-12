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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sampler)
        }
        .modelContainer(sharedModelContainer)
    }
}
