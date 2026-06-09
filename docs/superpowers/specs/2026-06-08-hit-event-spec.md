# Feature Spec — The "Hit Event" (juice-led slice)

**Date:** 2026-06-08
**Owner:** Defne (design)
**Status:** LOCKED — this is the event Diego juices and Khalid scores. Gate for all downstream juice work.
**Age band:** tuned to the **5-year-old floor**; 7yo served by the PERFECT tier. One spec, no separate tuning.

## Goal

Make _hitting the correct falling note_ the moment of fun — while the act of
hitting the **right key** quietly teaches the note→key map.

## Player verb

Kid sees a note falling toward a key → presses that key → **the note sounds on
their press** (not on the scroll). Agency = the difference between playing and
watching.

## The event — two checks, three outcomes

| Right key?                             | Timing vs hit line | Outcome     | Celebration                                              |
| -------------------------------------- | ------------------ | ----------- | -------------------------------------------------------- |
| ✅                                     | within **±250 ms** | **PERFECT** | biggest                                                  |
| ✅                                     | within **±600 ms** | **HIT**     | full (target: 90%+ of age-5 presses land here or better) |
| ❌ wrong key, OR no press past ±600 ms | —                  | **MISS**    | none — soft & kind                                       |

## Hard rules

1. **Right key is ALWAYS required for any celebration.** Timing is a bonus;
   key-correctness is the lesson. Never celebrate a wrong key, however well
   timed. This single rule protects the (deferred) pedagogy.
2. **Miss is soft.** Note dims, slides past, quiet. No buzzer, no red X, no
   score loss, no combo-break drama. (McMillen: remove frustration "at all
   costs." Carlsen: kids fail on input — never punish the input.)
3. **Sound fires on the kid's press**, via `PianoSampler.play`. Not on line-cross.

## Supporting numbers (to be playtested, not assumed)

- Perfect window: **±250 ms** | Hit window: **±600 ms** (adult rhythm games run
  ±30–50 ms — far too tight for age 5).
- Note visible & approaching **≥1.5 s** before the line (lead time to aim).
- Test-song tempo **60–80 BPM** (120 is unplayable at this age).
- Windows are in **ms**; implementation converts to pixels via scroll speed.

## Combo

Consecutive HITs escalate the celebration (the "one more" hook). A broken combo
does **not** punish — it stops escalating. No drama.

## Skill atom (the learning)

"_This_ falling note means _this_ key." press → sound → kid builds note→key map
→ tested by day-3 unprompted reopen. Daniel Cook, chemistry of game design.

## NOT in this slice (holding the scope cap)

Numeric score, stars, fail-the-song state, leaderboard, progression. Three
outcomes and celebration tiers only. Scoring = the loop-led slice, later.

## Success metric / kill criteria

- **Works:** a 5-year-old presses the **right key** (not any key) and grins;
  reopens unprompted on day 3 (Zeynep 5 / Ada 7, or Mei's panel).
- **Broken:** can't connect a falling note to its key after a few tries → the
  note→key **visual** mapping is wrong (Aiko/Diego), not these windows.

## Open questions (for Diego / Aiko)

- Does PERFECT vs HIT need distinct visual language a 5yo can read, or is
  PERFECT just "more of the same juice"? (Defne leans: more of the same, louder.)
- Column→key alignment is already 1:1 in `FallingNotesScene` — confirm it
  survives the juice layer.
