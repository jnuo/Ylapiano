import SwiftUI
import SwiftData
import UIKit

/// The app supports every orientation (iPad multitasking requires it), but
/// gameplay forces landscape — a piano keyboard needs the width. The system
/// queries this delegate whenever orientation support is re-evaluated;
/// `PlayerScreen` flips the lock via `OrientationGate` on appear / disappear.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .all
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}

/// Drives the orientation lock + an active rotation request. Lock alone only
/// constrains *future* rotation; `requestGeometryUpdate` actively turns the
/// device into landscape when gameplay opens.
enum OrientationGate {
    static func lockLandscape() { apply(.landscape, rotateTo: .landscapeRight) }
    static func unlock() { apply(.all, rotateTo: nil) }

    private static func apply(_ lock: UIInterfaceOrientationMask, rotateTo: UIInterfaceOrientationMask?) {
        AppDelegate.orientationLock = lock
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        if let rotateTo {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: rotateTo))
        }
    }
}

@main
struct YlapianoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
