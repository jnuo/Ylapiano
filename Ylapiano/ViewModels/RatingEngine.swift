import Foundation
import StoreKit
import UIKit

// MARK: - Trigger logic (B28 #39)

/// Decides WHEN Ylapiano may ask for an App Store rating. Reviews are the
/// only social proof a zero-UA launch gets, so the ask must land at the
/// moment of pride and never anywhere else. The rules, in the order they
/// veto:
///
///  1. **Silent under UI tests** — any launch carrying the test-only
///     `-hasCompletedOnboarding` override (every UI test injects it; no real
///     launch does — same heuristic `IntroGate` ships) or an explicit
///     `-b28-disable-rating` never asks, so the system dialog can't eat a
///     test's tap.
///  2. **Good result only** — the run that triggers the ask must be 2–3
///     stars. A 1-star screen is the wrong emotional moment; it still counts
///     toward the completion total, but never asks.
///  3. **Never the first session** — the household is still deciding whether
///     they like the app; asking on day one is hostile.
///  4. **Only after the Nth finished song** (N = 3, lifetime) — "finished a
///     few songs" is the proxy for "actually uses this".
///  5. **Once per session, once per app version** — a version that already
///     asked stays quiet until the next release.
///  6. **Max 3 asks per rolling year** — Apple enforces this system-side;
///     we track it ourselves so the engine never even *tries* a fourth.
///
/// Pure bookkeeping over an injected `UserDefaults` + clock, so every rule is
/// unit-testable. The system dialog itself is `ReviewAsk`'s job.
final class RatingEngine {
    static let minStars = 2
    static let minCompletions = 3
    static let minSessions = 2
    static let maxAsksPerYear = 3
    static let yearSeconds: TimeInterval = 365 * 24 * 60 * 60

    enum Keys {
        static let sessionCount = "b28-session-count"
        static let completionCount = "b28-completion-count"
        static let lastAskedVersion = "b28-last-asked-version"
        static let askDates = "b28-ask-dates"
    }

    private let defaults: UserDefaults
    private let version: String
    private let disabled: Bool
    private let now: () -> Date

    /// The in-session latch: even across version-string edge cases, one
    /// process asks at most once.
    private(set) var askedThisSession = false

    init(
        defaults: UserDefaults = .standard,
        version: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
        arguments: [String] = ProcessInfo.processInfo.arguments,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.version = version
        self.disabled = arguments.contains("-hasCompletedOnboarding")
            || arguments.contains("-b28-disable-rating")
        self.now = now
    }

    var sessionCount: Int { defaults.integer(forKey: Keys.sessionCount) }
    var completionCount: Int { defaults.integer(forKey: Keys.completionCount) }
    var askDates: [Date] {
        let stamps = defaults.array(forKey: Keys.askDates) as? [Double] ?? []
        return stamps.map(Date.init(timeIntervalSince1970:))
    }

    /// One real app launch = one session. Call exactly once per process
    /// (`ReviewAsk.registerSessionOnce()` owns the once-guard).
    func registerSessionStart() {
        defaults.set(sessionCount + 1, forKey: Keys.sessionCount)
    }

    /// Fold one finished song into the counters and decide whether THIS is
    /// the moment to ask. Returns true exactly when the system review prompt
    /// should be requested; recording the ask (date + version + session
    /// latch) happens atomically with the `true`.
    func recordCompletion(stars: Int) -> Bool {
        defaults.set(completionCount + 1, forKey: Keys.completionCount)

        guard !disabled else { return false }
        guard stars >= Self.minStars else { return false }
        guard sessionCount >= Self.minSessions else { return false }
        guard completionCount >= Self.minCompletions else { return false }
        guard !askedThisSession else { return false }
        guard defaults.string(forKey: Keys.lastAskedVersion) != version else { return false }

        let cutoff = now().addingTimeInterval(-Self.yearSeconds)
        let recentAsks = askDates.filter { $0 > cutoff }
        guard recentAsks.count < Self.maxAsksPerYear else { return false }

        askedThisSession = true
        defaults.set(version, forKey: Keys.lastAskedVersion)
        defaults.set(
            (recentAsks + [now()]).map(\.timeIntervalSince1970),
            forKey: Keys.askDates
        )
        return true
    }
}

// MARK: - System prompt presenter

/// The app-facing face of B28: owns the shared engine, the once-per-process
/// session registration, and the StoreKit call. The organic path
/// (`songCompleted`) runs the engine's gates; the Grown-Ups corner's explicit
/// "Rate Ylapiano" row calls `presentSystemPrompt()` directly — an adult
/// deliberately chose it, no gating needed (the system still rate-limits).
@MainActor
enum ReviewAsk {
    static let engine = RatingEngine()
    private static var sessionRegistered = false

    static func registerSessionOnce() {
        guard !sessionRegistered else { return }
        sessionRegistered = true
        engine.registerSessionStart()
    }

    /// A song just finished — the result overlay is up. If the engine says
    /// this is the moment, let the stars land first (the pop sequence runs
    /// ~1.5 s), then raise the system dialog over the result screen: the
    /// result/home boundary, never mid-play.
    static func songCompleted(stars: Int) {
        guard engine.recordCompletion(stars: stars) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.8))
            presentSystemPrompt()
        }
    }

    /// `SKStoreReviewController.requestReview`'s modern, non-deprecated
    /// spelling (StoreKit's `AppStore.requestReview(in:)`, iOS 16+) — the
    /// identical system rating dialog. Apple decides whether it actually
    /// shows (max 3/year system-wide, never in TestFlight review-capped
    /// contexts); we never block on it.
    static func presentSystemPrompt() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }
        AppStore.requestReview(in: scene)
    }
}
