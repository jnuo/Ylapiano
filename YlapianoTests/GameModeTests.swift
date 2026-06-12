import XCTest
@testable import Ylapiano

/// B4 (#21): the 4-rung mastery ladder is Salta-only; every other song plays
/// a fixed gentle config — full guidance, rung-1 windows, the song's own BPM.
@MainActor
final class GameModeTests: XCTestCase {

    private func saltaSong() -> Song {
        SeedData.createSeedSongs().first { $0.seedID == "plim-plim" }!
    }

    private func twinkleSong() -> Song {
        SeedData.createSeedSongs().first { $0.seedID == "twinkle-twinkle" }!
    }

    // MARK: - Sub-task 1: non-Salta songs pinned to the gentle config

    func testNonSaltaSongUsesGentleConfig() {
        let song = twinkleSong()   // bpm 80 in the catalog
        let vm = PlayerViewModel(song: song)

        XCTAssertFalse(vm.hasMasteryLadder)
        XCTAssertEqual(vm.metronome.bpm, song.bpm, "non-ladder songs keep their own BPM")
        XCTAssertEqual(vm.hitJudge.hitWindowMs, 600, "rung-1 wide HIT window")
        XCTAssertEqual(vm.hitJudge.perfectWindowMs, 250, "rung-1 PERFECT window")
        XCTAssertTrue(vm.guidedMode, "full key-glow guidance stays on")
    }

    func testUserSongIsNotOnTheLadder() {
        let userSong = Song(title: "Deniz's Own", bpm: 70, notes: [
            NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
        ])
        let vm = PlayerViewModel(song: userSong)

        XCTAssertFalse(vm.hasMasteryLadder)
        XCTAssertEqual(vm.metronome.bpm, 70)
    }

    func testNonSaltaSongNeverOffersTheClimb() {
        let vm = PlayerViewModel(song: twinkleSong())
        vm.simulateFinish(stars: 3)

        XCTAssertFalse(vm.canClimb, "climb is ladder-only")
        XCTAssertNil(vm.resultRungName, "no ladder language off the ladder")
    }

    // MARK: - Salta keeps the full ladder (no regression)

    func testSaltaOpensOnRungOneAndCanClimb() {
        let vm = PlayerViewModel(song: saltaSong())

        XCTAssertTrue(vm.hasMasteryLadder)
        XCTAssertEqual(vm.metronome.bpm, MasteryLadder.rungs[0].bpm)
        XCTAssertEqual(vm.resultRungName, MasteryLadder.rungs[0].name)

        vm.simulateFinish(stars: 3)
        XCTAssertTrue(vm.canClimb, "clean 3-star Salta run offers the climb")

        vm.climbRung()
        XCTAssertEqual(vm.metronome.bpm, MasteryLadder.rungs[1].bpm,
                       "climb advances to rung 2 tempo")
    }

    func testSaltaThreeStarsAtTopRungCannotClimb() {
        let vm = PlayerViewModel(song: saltaSong())
        while vm.canClimbAfterSimulatedThreeStars() {}
        XCTAssertFalse(vm.canClimb, "top rung has nowhere to climb")
    }
}

private extension PlayerViewModel {
    /// Drive the end-of-song state the way finishSong does, without playing.
    func simulateFinish(stars: Int) {
        setResult(stars: stars)
    }

    /// One simulated 3-star finish + climb if offered; false when no climb left.
    func canClimbAfterSimulatedThreeStars() -> Bool {
        simulateFinish(stars: 3)
        guard canClimb else { return false }
        climbRung()
        return true
    }
}
