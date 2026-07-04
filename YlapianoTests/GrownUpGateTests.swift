import XCTest
@testable import Ylapiano

/// B10 (#22) — the grown-up gate's hold rules, plus regressions for the three
/// findings PR #33 punted here: the BPM-stepper reset, the silent sheet-music
/// ending, and the ladder-owned Salta BPM.
@MainActor
final class GrownUpGateTests: XCTestCase {

    // MARK: - Hold-gate logic

    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    func testQuickKidTapNeverUnlocks() {
        let gate = HoldGateModel()
        gate.begin(at: t0)
        // A kid-style tap: down + up within ~150 ms.
        XCTAssertFalse(gate.update(now: t0.addingTimeInterval(0.15)))
        gate.cancel()
        XCTAssertFalse(gate.isHolding)
        XCTAssertEqual(gate.progress, 0, "a cancelled tap leaves no partial ring")
    }

    func testProgressRampsWhileHeld() {
        let gate = HoldGateModel(requiredHold: 2.5)
        gate.begin(at: t0)
        XCTAssertFalse(gate.update(now: t0.addingTimeInterval(1.25)))
        XCTAssertEqual(gate.progress, 0.5, accuracy: 0.001, "half the hold = half the ring")
        XCTAssertTrue(gate.isHolding)
    }

    func testUnlocksAtRequiredHold() {
        let gate = HoldGateModel(requiredHold: 2.5)
        gate.begin(at: t0)
        XCTAssertFalse(gate.update(now: t0.addingTimeInterval(2.4)), "just short of the hold — still locked")
        XCTAssertTrue(gate.update(now: t0.addingTimeInterval(2.5)), "a deliberate adult hold unlocks")
        XCTAssertFalse(gate.update(now: t0.addingTimeInterval(2.6)),
                       "unlock fires exactly once per hold; the model resets")
    }

    func testReleaseBeforeThresholdCancelsAndResets() {
        let gate = HoldGateModel(requiredHold: 2.5)
        gate.begin(at: t0)
        _ = gate.update(now: t0.addingTimeInterval(2.0))
        gate.cancel()
        XCTAssertFalse(gate.isHolding)
        XCTAssertEqual(gate.progress, 0)
        // A fresh attempt starts over from zero — no credit carries across.
        gate.begin(at: t0.addingTimeInterval(3))
        XCTAssertFalse(gate.update(now: t0.addingTimeInterval(3.6)),
                       "prior 2.0 s of holding must not count toward the new attempt")
    }

    func testUpdateWithoutBeginIsInert() {
        let gate = HoldGateModel()
        XCTAssertFalse(gate.update(now: t0))
        XCTAssertEqual(gate.progress, 0)
    }

    func testDefaultHoldSitsInTheTwoToThreeSecondBand() {
        XCTAssertGreaterThanOrEqual(HoldGateModel.defaultHoldSeconds, 2.0)
        XCTAssertLessThanOrEqual(HoldGateModel.defaultHoldSeconds, 3.0)
    }

    // MARK: - PR #33 residual 1: adult BPM survives a fresh play

    private func twinkle() -> Song {
        SeedData.createSeedSongs().first { $0.seedID == "twinkle-twinkle" }!
    }

    private func salta() -> Song {
        SeedData.createSeedSongs().first { $0.seedID == "plim-plim" }!
    }

    func testAdultBPMSurvivesFreshPlay() {
        let vm = PlayerViewModel(song: twinkle())
        vm.setBPM(120)
        vm.startPlaying()
        XCTAssertEqual(vm.metronome.bpm, 120,
                       "applyRung() must not clobber the drawer-set tempo on a fresh play")
        vm.stopPlaying()
        vm.startPlaying()
        XCTAssertEqual(vm.metronome.bpm, 120, "…nor on any later fresh play")
    }

    func testAdultBPMSurvivesFreshPlayOnTheLadderSong() {
        let vm = PlayerViewModel(song: salta())
        vm.setBPM(60)
        vm.startPlaying()
        XCTAssertEqual(vm.metronome.bpm, 60,
                       "the drawer override outranks the rung tempo until a climb")
    }

    func testClimbClearsTheAdultOverride() {
        let vm = PlayerViewModel(song: salta())
        vm.setBPM(60)
        vm.setResult(stars: 3)   // clean run → climb on offer
        XCTAssertTrue(vm.canClimb)
        vm.climbRung()
        XCTAssertEqual(vm.metronome.bpm, MasteryLadder.rungs[1].bpm,
                       "\"Faster!\" must actually get faster — the climb re-owns the tempo")
        XCTAssertNil(vm.bpmOverride)
    }

    func testNoOverrideKeepsExistingTempoBehavior() {
        let song = twinkle()
        let vm = PlayerViewModel(song: song)
        vm.startPlaying()
        XCTAssertEqual(vm.metronome.bpm, song.bpm,
                       "without a drawer override, fresh plays keep the song's own BPM (B4)")
    }

    func testSetBPMClampsToTheStepperRange() {
        let vm = PlayerViewModel(song: twinkle())
        vm.setBPM(10)
        XCTAssertEqual(vm.metronome.bpm, 40)
        vm.setBPM(999)
        XCTAssertEqual(vm.metronome.bpm, 220)
    }

    // MARK: - PR #33 residual 2: sheet-music runs never end in silence

    func testSheetPlaybackEndRaisesFeedbackWithoutStars() {
        let vm = PlayerViewModel(song: twinkle())
        vm.startPlaying()
        vm.finishSheetPlayback()
        XCTAssertTrue(vm.sheetRunEnded, "the run gets an acknowledgement toast")
        XCTAssertFalse(vm.isPlaying)
        XCTAssertFalse(vm.songFinished, "no result screen — stars require judged play")
        XCTAssertEqual(vm.resultStars, 0, "unjudged sheet playback mints no stars")
    }

    func testSheetFeedbackClearsOnAcknowledgeAndOnFreshPlay() {
        let vm = PlayerViewModel(song: twinkle())
        vm.startPlaying()
        vm.finishSheetPlayback()
        vm.acknowledgeSheetRun()
        XCTAssertFalse(vm.sheetRunEnded)

        vm.startPlaying()
        vm.finishSheetPlayback()
        XCTAssertTrue(vm.sheetRunEnded)
        vm.startPlaying()
        XCTAssertFalse(vm.sheetRunEnded, "a fresh play sweeps any stale toast")
        vm.stopPlaying()
    }

    func testSheetFinishWhileNotPlayingIsInert() {
        let vm = PlayerViewModel(song: twinkle())
        vm.finishSheetPlayback()
        XCTAssertFalse(vm.sheetRunEnded, "spurious end callbacks while stopped do nothing")
    }

    // MARK: - PR #33 residual 3: ladder tempo ownership lives on the model

    func testOnlyTheLadderSongIsLadderOwned() {
        XCTAssertTrue(salta().hasMasteryLadder)
        XCTAssertFalse(twinkle().hasMasteryLadder)
        XCTAssertFalse(Song(title: "Mine", bpm: 90).hasMasteryLadder,
                       "user songs are never ladder-owned")
    }
}
