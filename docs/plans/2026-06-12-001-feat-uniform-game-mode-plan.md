---
title: "feat: Uniform game mode + stars/Pim result for every song (B4, #21)"
type: feat
date: 2026-06-12
origin: https://github.com/jnuo/Ylapiano/issues/21
---

# feat: Uniform game mode + stars/Pim result for every song

**Target branch:** `feat/B4-uniform-game-mode`, based on `feat/B2-final-13-catalog` (B2 is In Review; B4 depends on its 13-song catalog). PR base = `feat/B2-final-13-catalog` (stacked).

---

## Summary

Make falling-notes-with-result the one game experience for all 13 songs: every song plays at a gentle fixed difficulty and ends in `SongResultView` (stars + Pim). The full 4-rung mastery ladder stays exclusive to Salta (`plim-plim`). The competing flat "Great job!" completion card is deleted.

Out of scope: persistence of stars/rung (**B3**, #13), Kid Mode control gating (**B10**, #22), result-screen sound (**B11**, #16).

---

## Problem Frame

The mastery ladder was built for the single-song era and currently applies to **every** song: `PlayerViewModel.init` calls `applyRung()` unconditionally, so all 13 catalog songs play at rung-1's 50 BPM (ignoring their per-song BPM from B2), and any song offers the "climb" after 3 stars. Meanwhile sheet-music mode ends in a flat `completionOverlay` text card instead of the stars/Pim result. Issue #21 locks the intended shape: uniform gentle game mode per song, ladder Salta-only, one celebratory result path.

## Requirements (from issue #21 sub-tasks)

- **R1** — Non-Salta songs are pinned to a fixed gentle config; the rung ladder (and climbing) is gated to `seedID == "plim-plim"`. _(sub-task 1)_
- **R2** — Every completion routes through `SongResultView` (stars + Pim); the sheet-music "Great job!" overlay is deleted. _(sub-task 2)_
- **R3** — All 13 songs verified end-to-end: launch → falling-notes → result screen. _(sub-task 3; device checklist is Onur's gate, sim spot-checks are prep)_

---

## Key Technical Decisions

1. **Gate by capability flag, not scattered seedID checks.** `PlayerViewModel` gets one derived `hasMasteryLadder` (true iff `song.seedID == "plim-plim"`), consulted by `applyRung()`, `canClimb`, and the result-view inputs. No other file should compare seedIDs.
2. **Fixed gentle config = rung-1 guidance + rung-1 windows + the song's own BPM.** Rung 1's 50 BPM was tuned for Salta (natural 60); forcing Kırmızı Balık (90) or Ali Baba (100) to 50 kills the songs' feel and discards B2's per-song kid-friendly tempos. "Gentle" is carried by full key-glow guidance and the forgiving 600/250 ms windows. _(Alternative — strict rung-1 50 BPM for everything — rejected; flagged for Onur at review since the issue's test-gate wording says "slow".)_
3. **Rung name hidden off-ladder.** `SongResultView` shows the rung name ("Learn the keys" …) only for Salta; non-ladder songs pass nil and the label collapses. Ladder language on non-ladder songs would be noise for a 5-year-old.
4. **Sheet-music mode ends quietly.** Falling-notes is already the default `displayMode` and the only judged mode; `SongResultView` requires judged play for honest stars. Sheet playback end keeps `stopPlaying()` with no card at all (the flat card is deleted, not replaced) — stars come only from the game. The mic-driven advance path that fed the old overlay is being removed wholesale by B5 anyway.

---

## Implementation Units

### U1. Gate the mastery ladder to Salta; pin everything else to the gentle config

**Goal:** Non-Salta songs play at full guidance, 600/250 ms windows, own BPM; no climb offer. Salta keeps the 4-rung ladder unchanged.
**Requirements:** R1
**Dependencies:** none
**Files:** `Ylapiano/ViewModels/PlayerViewModel.swift`, `YlapianoTests/GameModeTests.swift` (new; add to `Ylapiano.xcodeproj/project.pbxproj` test target following the manual-reference pattern used for `CatalogTests.swift`)
**Approach:** Add `hasMasteryLadder` derived from `song.seedID`. `applyRung()` branches: ladder songs apply `MasteryLadder.rungs[rungIndex]` as today; others apply guidance `.full`, windows 600/250, `metronome.bpm = song.bpm`. `canClimb` requires `hasMasteryLadder`. Expose what the result view needs (e.g. `resultRungName: String?` nil when off-ladder).
**Test scenarios:**

- Non-Salta song (e.g. seeded Twinkle, bpm 80): after init, `metronome.bpm == 80`, `hitJudge.hitWindowMs == 600`, `perfectWindowMs == 250`, `guidedMode == true`.
- Non-Salta song with `songFinished = true` and 3-star result: `canClimb == false`; `resultRungName == nil`.
- Salta (`plim-plim`): init applies rung 1 (bpm 50); after a 3-star finish `canClimb == true`; `climbRung()` advances to rung 2 (bpm 70) — existing behavior unregressed.
- User-created song (`seedID == nil`): treated as non-ladder (own bpm, no climb).
  **Verification:** new unit tests green; existing `YlapianoTests` green.

### U2. One completion path: delete the flat card, gate the rung label

**Goal:** `SongResultView` is the only end-of-song surface; "Great job!" overlay and its trigger are gone.
**Requirements:** R2
**Dependencies:** U1 (consumes `resultRungName`)
**Files:** `Ylapiano/Views/PlayerScreen.swift`
**Approach:** Delete `completionOverlay` and its `.overlay { if viewModel.isComplete … }` block; `SongResultView.rungName` becomes optional and the label row renders only when present. Sheet-mode `onPlaybackEnd` keeps quiet `stopPlaying()`.
**Test scenarios:** Test expectation: unit-light — this unit is view deletion/plumbing; behavior is covered by U1's `resultRungName` tests plus build success and U3's on-sim verification (finish a non-Salta song in falling-notes → stars/Pim result appears, no flat card; no rung label for non-Salta; rung label + climb intact for Salta).
**Verification:** app builds; sim run shows the result screen for Twinkle with no rung label and no climb button; Salta still shows rung name + climb at 3 stars.

### U3. End-to-end verification pass (sim prep for Onur's device checklist)

**Goal:** Evidence that every song launches falling-notes and ends in the result screen.
**Requirements:** R3
**Dependencies:** U1, U2
**Files:** none (verification artifacts to `~/Downloads/` + issue #21 comment)
**Approach:** On sim `3D089F92-5F63-473D-B8A9-191EFBF238BF`: spot-check a representative set (Salta, Twinkle, Kırmızı Balık, Cargol — the one with a rest, Itsy — dotted durations), screenshot the result screen; post the 13-box device checklist on issue #21 for Onur.
**Test scenarios:** Test expectation: none — manual/sim verification unit; the device checklist is Onur's human gate (issue sub-task 3).
**Verification:** screenshots delivered; checklist comment posted.

---

## Scope Boundaries

- **Deferred to Follow-Up Work:** persisting `bestStars`/`bestRung` (B3 #13); hiding sheet/edit/mode controls from kids (B10 #22); result-screen audio (B11 #16); pre-reader icon pass on the result screen (B14 #19).
- **Non-goals:** changing ladder rung numbers; redesigning `SongResultView` visuals; touching the B2 catalog data.

## Risks

- **Stacked branch:** B2 may get review changes; rebase `feat/B4-uniform-game-mode` before ship if B2 moves.
- **Test-gate wording ("slow"):** KTD 2 interprets "gentle" as guidance+windows, not 50 BPM. If Onur wants literal rung-1 tempo, it's a one-line change in `applyRung()`.

## Open Questions

- None blocking. KTD 2 (own-BPM vs 50 BPM) flagged for Onur at In Review.
