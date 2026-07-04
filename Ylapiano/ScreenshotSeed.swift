import Foundation

/// B20 (#20) — the one launch-argument mechanism that puts the app into
/// picture-perfect, deterministic store states:
///
///     -screenshotState home      seeded star spread on the library grid
///     -screenshotState playing   frozen mid-play falling-notes moment
///     -screenshotState result    3-star result with the handoff card
///
/// Turkish variants: add `-AppleLanguages (tr) -AppleLocale tr_TR` (and
/// `-hasCompletedOnboarding YES` so onboarding/intro never cover the shot).
/// `StoreScreenshotsUITests` is the capture harness that drives these.
///
/// It CONSOLIDATES the earlier per-card demo hooks — `-b9-demo-stars`
/// (HomeScreen star spread) and `-b26-demo-result-stars N` (instant result) —
/// which now parse through here as legacy aliases, so the older UI tests
/// keep working against one mechanism instead of three.
///
/// **Guarding.** This type is always compiled (it's pure parsing), but every
/// query is inert unless `isEnabled` — which is true only under `DEBUG` or a
/// dedicated `STORE_CAPTURE` compilation condition. Release/App Store builds
/// ignore the argument entirely; if B21 ever needs device screenshots off a
/// release-config build, build with
/// `SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) STORE_CAPTURE`
/// instead of weakening the DEBUG guard.
///
/// **Determinism contract.** While a profile is active (`freezeMotion`):
/// Pim's home idle renders the static still, the result screen's looping
/// reward clip renders the static pose, and the mid-play state freezes the
/// shared play clock (`PlayerViewModel.freezeForScreenshot`) — no count-in
/// overlay, no advancing notes, no star-pop mid-shot.
enum ScreenshotSeed {

    enum Profile: String {
        case home
        case playing
        case result
    }

    /// Config-conditional switch: seeding exists in DEBUG / store-capture
    /// builds only. Injected into the parsers so tests can prove the
    /// disabled (Release) path ignores the argument.
    static var isEnabled: Bool {
        #if DEBUG || STORE_CAPTURE
        true
        #else
        false
        #endif
    }

    /// The active profile for this launch, or nil (production launch, no
    /// argument, or an unknown profile name).
    static func profile(
        from arguments: [String] = ProcessInfo.processInfo.arguments,
        enabled: Bool = isEnabled
    ) -> Profile? {
        guard enabled else { return nil }
        if let value = value(after: "-screenshotState", in: arguments) {
            return Profile(rawValue: value)
        }
        // Legacy demo hooks, consolidated (B9 / B26).
        if arguments.contains("-b9-demo-stars") { return .home }
        if legacyResultStars(in: arguments) != nil { return .result }
        return nil
    }

    /// True whenever any profile is active — views read this to freeze
    /// ambient motion (Pim idle, looping reward clip) for pixel-stable shots.
    /// Always false when disabled, so call sites need no #if of their own.
    static var freezeMotion: Bool { profile() != nil }

    // MARK: - home

    /// The designed star spread for the library shot (B21 "library-with-
    /// stars" frame): a believable mid-journey mix of 3/2/1/0 across the 13
    /// catalog cards — early songs earned, the tail still open, no flat rows.
    /// Applied by grid order (`Song.sortOrder`), modulo-safe if the catalog
    /// ever grows.
    static let homeStarSpread: [Int] = [3, 2, 3, 1, 0, 2, 3, 0, 1, 2, 0, 1, 2]

    // MARK: - playing

    /// Where the mid-play clock freezes, in elapsed beats from Play:
    /// the 4-beat lead-in (`HitJudge.leadInBeats`) + 2.5 beats into the song,
    /// so the lanes are full and one note sits just above the hit line.
    static let playingFreezeBeats: Double = 6.5

    // MARK: - result

    /// Stars for the seeded result screen. `-screenshotState result`
    /// defaults to the 3-star hero; the legacy `-b26-demo-result-stars N`
    /// spelling picks an explicit tier (clamped 1...3). nil = no result seed.
    static func resultStars(
        from arguments: [String] = ProcessInfo.processInfo.arguments,
        enabled: Bool = isEnabled
    ) -> Int? {
        guard profile(from: arguments, enabled: enabled) == .result else { return nil }
        if let stars = legacyResultStars(in: arguments) { return stars }
        return 3
    }

    // MARK: - Parsing helpers

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.index(after: index) < arguments.endIndex else { return nil }
        return arguments[arguments.index(after: index)]
    }

    /// `-b26-demo-result-stars N` for N ≥ 1, clamped to 3 (matches the
    /// original hook's `stars > 0` guard + `min(stars, 3)` clamp).
    private static func legacyResultStars(in arguments: [String]) -> Int? {
        guard let raw = value(after: "-b26-demo-result-stars", in: arguments),
              let stars = Int(raw), stars > 0 else { return nil }
        return min(stars, 3)
    }
}
