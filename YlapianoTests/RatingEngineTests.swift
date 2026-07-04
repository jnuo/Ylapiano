import XCTest
@testable import Ylapiano

/// B28 (#39) — the rating engine's trigger rules, exercised against a scratch
/// `UserDefaults` suite with injected clock/version/arguments so every gate
/// is deterministic: Nth completion, good-result-only, never-first-session,
/// once-per-session, once-per-version, the 3-per-year budget, persistence,
/// and the UI-test launch-arg silence.
final class RatingEngineTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        suiteName = "b28-rating-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func makeEngine(
        version: String = "1.4.10",
        arguments: [String] = [],
        now: Date? = nil
    ) -> RatingEngine {
        let fixed = now ?? t0
        return RatingEngine(defaults: defaults, version: version,
                            arguments: arguments, now: { fixed })
    }

    /// An engine in an "eligible" world: second session already registered.
    private func makeSecondSessionEngine(version: String = "1.4.10", now: Date? = nil) -> RatingEngine {
        let engine = makeEngine(version: version, now: now)
        engine.registerSessionStart()
        engine.registerSessionStart()
        return engine
    }

    // MARK: - The Nth-completion gate

    func testNeverAsksBeforeTheThirdCompletion() {
        let engine = makeSecondSessionEngine()
        XCTAssertFalse(engine.recordCompletion(stars: 3), "1st finished song — too early")
        XCTAssertFalse(engine.recordCompletion(stars: 3), "2nd finished song — too early")
    }

    func testAsksOnTheThirdCompletionWithAGoodResult() {
        let engine = makeSecondSessionEngine()
        _ = engine.recordCompletion(stars: 3)
        _ = engine.recordCompletion(stars: 2)
        XCTAssertTrue(engine.recordCompletion(stars: 2),
                      "3rd completion + 2-star result + 2nd session = the moment of pride")
    }

    // MARK: - Good result only

    func testAOneStarResultNeverTriggersTheAsk() {
        let engine = makeSecondSessionEngine()
        for _ in 0..<5 {
            XCTAssertFalse(engine.recordCompletion(stars: 1),
                           "a 1-star screen is the wrong emotional moment — never ask")
        }
        // 1-star runs still counted toward N, so the next good run asks.
        XCTAssertTrue(engine.recordCompletion(stars: 2),
                      "the first GOOD result after the threshold asks")
    }

    // MARK: - Never the first session

    func testNeverAsksInTheFirstSession() {
        let engine = makeEngine()
        engine.registerSessionStart()   // session 1 only
        for _ in 0..<5 {
            XCTAssertFalse(engine.recordCompletion(stars: 3),
                           "first-session asks are hostile — never")
        }
    }

    // MARK: - Once per session / once per version

    func testNeverAsksTwiceInTheSameSessionOrVersion() {
        let engine = makeSecondSessionEngine()
        _ = engine.recordCompletion(stars: 3)
        _ = engine.recordCompletion(stars: 3)
        XCTAssertTrue(engine.recordCompletion(stars: 3))
        XCTAssertTrue(engine.askedThisSession, "the grant latches the session")
        XCTAssertFalse(engine.recordCompletion(stars: 3), "same session — silent")

        // A fresh launch (new engine, same store, same version) stays silent.
        let relaunch = makeEngine()
        relaunch.registerSessionStart()
        XCTAssertFalse(relaunch.recordCompletion(stars: 3),
                       "this version already asked — quiet until the next release")
    }

    func testANewVersionMayAskAgain() {
        let engine = makeSecondSessionEngine(version: "1.4.10")
        _ = engine.recordCompletion(stars: 3)
        _ = engine.recordCompletion(stars: 3)
        XCTAssertTrue(engine.recordCompletion(stars: 3))

        let updated = makeEngine(version: "1.5.0", now: t0.addingTimeInterval(14 * 86_400))
        updated.registerSessionStart()
        XCTAssertTrue(updated.recordCompletion(stars: 3),
                      "a new version with budget left asks again")
    }

    // MARK: - 3-per-year budget

    func testRespectsTheThreeAsksPerYearBudget() {
        // Burn the year's budget across three versions. After the first
        // version's warm-up, every later version asks on its FIRST good run
        // (all thresholds already met).
        for (i, version) in ["1.0", "1.1", "1.2"].enumerated() {
            let engine = makeEngine(version: version, now: t0.addingTimeInterval(Double(i) * 86_400))
            engine.registerSessionStart()
            if i == 0 {
                engine.registerSessionStart()   // reach session ≥ 2 once
                _ = engine.recordCompletion(stars: 3)
                _ = engine.recordCompletion(stars: 3)   // reach completion ≥ 3 once
            }
            XCTAssertTrue(engine.recordCompletion(stars: 3), "ask #\(i + 1) fits the budget")
        }

        // A fourth version 10 days later: budget exhausted.
        let fourth = makeEngine(version: "1.3", now: t0.addingTimeInterval(10 * 86_400))
        fourth.registerSessionStart()
        XCTAssertFalse(fourth.recordCompletion(stars: 3),
                       "3 asks inside a rolling year — the 4th must wait")

        // The same fourth version 400 days out: the old asks fell out of the window.
        let nextYear = makeEngine(version: "1.3", now: t0.addingTimeInterval(400 * 86_400))
        nextYear.registerSessionStart()
        XCTAssertTrue(nextYear.recordCompletion(stars: 3),
                      "the rolling-year window frees the budget")
    }

    // MARK: - UI-test silence (the launch-arg guard)

    func testUITestLaunchesNeverAsk() {
        // Every UI test injects -hasCompletedOnboarding (no real launch
        // does — IntroGate's validated heuristic); the explicit kill-switch
        // works too.
        for args in [["-hasCompletedOnboarding", "YES"], ["-b28-disable-rating"]] {
            let fresh = "b28-uitest-\(UUID().uuidString)"
            let d = UserDefaults(suiteName: fresh)!
            defer { d.removePersistentDomain(forName: fresh) }
            let engine = RatingEngine(defaults: d, version: "1.4.10",
                                      arguments: args, now: { self.t0 })
            engine.registerSessionStart()
            engine.registerSessionStart()
            for _ in 0..<5 {
                XCTAssertFalse(engine.recordCompletion(stars: 3),
                               "engine must be a silent no-op under \(args)")
            }
            XCTAssertEqual(engine.completionCount, 5,
                           "bookkeeping still runs — only the ASK is suppressed")
        }
    }

    // MARK: - Persistence

    func testCountersSurviveARelaunch() {
        let first = makeEngine()
        first.registerSessionStart()
        _ = first.recordCompletion(stars: 3)
        _ = first.recordCompletion(stars: 1)

        let second = makeEngine()
        second.registerSessionStart()
        XCTAssertEqual(second.sessionCount, 2, "sessions accumulate across launches")
        XCTAssertEqual(second.completionCount, 2, "completions accumulate across launches")
        // …and the restored state is exactly one good run away from the ask.
        XCTAssertTrue(second.recordCompletion(stars: 2))
    }
}
