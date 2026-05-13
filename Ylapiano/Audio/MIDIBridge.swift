import Foundation
import SwiftMIDIIO

/// Listens for USB MIDI input and forwards note-on/note-off events through
/// an `AsyncStream`. Owns one app-scoped `MIDIManager` so all incoming USB
/// MIDI sources auto-connect — plug a keyboard in mid-session and it just
/// works. PLAN.md Sprint 2's minimum viable slice: USB only, no Bluetooth,
/// no animated banner, no chime.
///
/// **Why a single stored stream** (not a fresh `AsyncStream` per access):
/// each `.task { for await … }` consumer would otherwise create its own
/// continuation, and the receive callback only ever writes to whichever was
/// most recently assigned. View re-appear after navigation would silently
/// orphan the previous continuation.
///
/// **Why bounded buffer** (`.bufferingNewest(32)`): the default policy is
/// unbounded; a stuck consumer would grow memory without limit. 32 events
/// at ~10 notes/sec is 3+ seconds of headroom — older notes past that point
/// are not musically useful anyway.
///
/// **Filtering noise**: the PSS-A50 sends pitch bend in B-PITCH motion mode,
/// modulation/expression/filter CCs in motion modes, MIDI Clock during
/// internal Phrase playback, and Active Sensing constantly. We forward
/// **only** note-on (vel > 0), note-on-vel-0 (running-status note-off form),
/// and note-off. Everything else is silently dropped.
@MainActor
final class MIDIBridge: ObservableObject {
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var lastError: String?

    let eventStream: AsyncStream<MIDIEvent>

    // App-scoped manager; no manual teardown needed — `MIDIManager` cleans
    // itself up on its own deinit.
    private let manager: MIDIManager
    private let continuation: AsyncStream<MIDIEvent>.Continuation

    private static let inputTag = "Ylapiano.AllSources"

    init() {
        let (stream, cont) = AsyncStream<MIDIEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(32)
        )
        self.eventStream = stream
        self.continuation = cont

        self.manager = MIDIManager(
            clientName: "Ylapiano",
            model: "iPad",
            manufacturer: "Ylapiano"
        )

        // The receiver closure runs on a CoreMIDI background thread. Only
        // filter + yield to the (thread-safe) continuation — never touch
        // main-actor state from here.
        let sink = continuation
        let receiver: MIDIReceiver = .events { events, _, _ in
            for event in events where Self.shouldForward(event) {
                sink.yield(event)
            }
        }

        do {
            try manager.start()
            try manager.addInputConnection(
                to: .allOutputs,
                tag: Self.inputTag,
                // `.default()` is a no-op filter — fine here because we don't
                // create virtual outputs that would need to be excluded.
                filter: .default(),
                receiver: receiver
            )
        } catch {
            print("[MIDIBridge] init failed: \(error.localizedDescription)")
            self.lastError = error.localizedDescription
        }

        // `notificationHandler` is typed as a `@Sendable` closure — hop to
        // `@MainActor` defensively before mutating `@Published` state.
        manager.notificationHandler = { [weak self] notification in
            switch notification {
            case .added, .removed, .setupChanged:
                Task { @MainActor in
                    self?.refreshConnectedState()
                }
            default:
                break
            }
        }

        refreshConnectedState()
    }

    nonisolated static func shouldForward(_ event: MIDIEvent) -> Bool {
        switch event {
        case .noteOn, .noteOff:
            return true
        default:
            return false
        }
    }

    private func refreshConnectedState() {
        let outputs = manager.endpoints.outputs
        let hasSource = !outputs.isEmpty
        if hasSource != isConnected {
            isConnected = hasSource
            print("[MIDIBridge] isConnected → \(hasSource), sources: \(outputs.map(\.displayName))")
        }
    }
}
