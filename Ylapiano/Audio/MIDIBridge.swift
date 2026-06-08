import Foundation
import SwiftMIDIIO

/// Thread-safe fan-out of MIDI events to any number of consumers. The
/// CoreMIDI receiver runs on a background thread and calls `yield` from
/// there; consumers register/unregister from the main actor. A plain lock
/// keeps the hot path off any actor so neither side blocks the other.
private final class MIDIEventFanOut: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<MIDIEvent>.Continuation] = [:]

    func add(_ continuation: AsyncStream<MIDIEvent>.Continuation) -> UUID {
        let id = UUID()
        lock.lock()
        continuations[id] = continuation
        lock.unlock()
        return id
    }

    func remove(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }

    func yield(_ event: MIDIEvent) {
        lock.lock()
        let live = Array(continuations.values)
        lock.unlock()
        // Yield outside the lock — a consumer's buffering policy must never
        // be able to stall the CoreMIDI receive thread under our lock.
        for continuation in live {
            continuation.yield(event)
        }
    }
}

/// Listens for USB MIDI input and forwards note-on/note-off events. Owns one
/// app-scoped `MIDIManager` so all incoming USB MIDI sources auto-connect —
/// plug a keyboard in mid-session and it just works. PLAN.md Sprint 2's
/// minimum viable slice: USB only, no Bluetooth, no animated banner, no chime.
///
/// **Why `events()` hands out a fresh stream per call** (not one shared
/// `AsyncStream`): an `AsyncStream` supports a single iteration for its whole
/// lifetime. A single stored stream means the SECOND consumer — e.g. opening
/// another song after navigating back — re-iterates an already-consumed
/// stream, which is unsupported and silently kills MIDI input after the first
/// screen. The fan-out registers each consumer's continuation and removes it
/// on termination (`.task` cancel on view disappear), so re-subscription is
/// safe and events are dropped (not stale-buffered) while no screen listens.
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

    // App-scoped manager; no manual teardown needed — `MIDIManager` cleans
    // itself up on its own deinit.
    private let manager: MIDIManager
    private let fanOut = MIDIEventFanOut()

    private static let inputTag = "Ylapiano.AllSources"

    /// A fresh event stream for one consumer. Safe to call again after a
    /// previous consumer's iteration is cancelled — each call registers its
    /// own continuation, unlike re-iterating a single shared `AsyncStream`.
    func events() -> AsyncStream<MIDIEvent> {
        AsyncStream(bufferingPolicy: .bufferingNewest(32)) { [fanOut] continuation in
            let id = fanOut.add(continuation)
            continuation.onTermination = { _ in
                fanOut.remove(id)
            }
        }
    }

    init() {
        self.manager = MIDIManager(
            clientName: "Ylapiano",
            model: "iPad",
            manufacturer: "Ylapiano"
        )

        // The receiver closure runs on a CoreMIDI background thread. Only
        // filter + fan out to the (thread-safe) registry — never touch
        // main-actor state from here.
        let fanOut = self.fanOut
        let receiver: MIDIReceiver = .events { events, _, _ in
            for event in events where Self.shouldForward(event) {
                fanOut.yield(event)
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
