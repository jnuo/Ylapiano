# Design Spec — Single-Song Mastery Ladder (Salta l'Esquirol)

**Owner:** Defne (design) · **Date:** 2026-06-09 · **Brief:** product/single-song-experience-brief.md

## The problem

One song must make a **5–7yo** _and_ an **adult** "play it better every time."
One difficulty serves neither.

## The insight (the whole design)

The **song is constant. Difficulty scales on three knobs.** Same notes, rising
challenge — exactly how a real instrument lets a kid and an adult practice the
same piece. "Play it better" stops being a vibe and becomes a **ladder you climb.**

Three knobs:

1. **Tempo** (BPM) — slow to fast.
2. **Guidance** — the target key glows on the keyboard in time with the falling
   note (the existing `guidedMode` / `expectedNote`). On → fading → off.
3. **Timing strictness** — the hit window. Wide (forgiving) → tight (precision).

## The ladder — 4 rungs, one song (starting numbers, tune in playtest)

| Rung | Name           | BPM | Guidance   | HIT window | PERFECT | Who lives here          |
| ---- | -------------- | --- | ---------- | ---------- | ------- | ----------------------- |
| 1    | Learn the keys | 50  | full glow  | ±600ms     | ±250ms  | 5yo floor               |
| 2    | Find the beat  | 70  | glow on    | ±450ms     | ±200ms  | 6–7yo                   |
| 3    | Play it        | 96  | glow fades | ±300ms     | ±150ms  | older kid / adult entry |
| 4    | Master it      | 120 | none       | ±150ms     | ±60ms   | adult ceiling           |

A 5yo lives happily on rungs 1–2; an adult climbs to 4. Same content. The kid
_feels_ themselves get better (slow→medium); the adult gets real mastery depth.

## Progression rules (never forced, never punished)

- **3-star a rung → the next rung is offered** with a big "Faster! / Lights off!"
  button. Climbing is the player's choice (a 5yo can stay on rung 2 forever — fine).
- **1–2 stars → replay this rung** ("2 of 3 — one more!").
- **Miss a lot as a young kid → gently rubber-band** (stay, or nudge slower).
  Never a down-rung punishment.
- Stars by accuracy on that rung (existing thresholds: ≥80%→3, ≥50%→2, else 1, min 1).

## The loop closes (Cook's skill atom, end to end)

play → **stars + near-miss** (which notes you missed) → **rung-up reward** →
**replay** (beat your best, or take the next rung). Both replay hooks pull:
_beat-your-best_ within a rung, _next rung_ across rungs.

## "Play better" mechanism — near-miss clarity

At the result, **show the notes you missed** (highlight those keys on the
keyboard / mark those falling-blocks). The player learns _exactly_ what to retry.
That's the difference between "I lost" and "I practice this bit."

## Identity held (the cut)

This stays a **kids-first** app — non-reader UI, kid voice, Apple Kids Category.
Adults get depth through the **higher rungs**, NOT a separate "adult mode," not
settings menus. Same one-tap experience; the ladder does the scaling. If it ever
needs an adult-only UI, that's a different product — backlog it.

## Built vs new

- **Built:** falling notes, hit detection + windows (`HitJudge`), stars + result,
  `guidedMode`/`expectedNote`, adjustable tempo, 4-beat lead-in, sparkle/juice.
- **New:** rung state + auto-progression; per-rung knob presets; near-miss display
  at result; rung-up celebration moment.

## Routing

- **Marco:** rung state + applying the 3 knobs per rung (tempo→metronome.bpm,
  guidance→guidedMode, window→HitJudge windows); capture per-note miss data for
  the near-miss display.
- **Diego + Khalid:** the **rung-up** celebration (bigger than a per-song win —
  it's "you leveled up"), + near-miss highlight motion.
- **Mei:** the gate — a 5yo climbs rung 1→2 across a sitting; an adult reaches
  rung 3–4; both replay unprompted; miss-curve drops.

## Dependency / flag

This assumes Salta l'Esquirol's **notes are correct** — still pending Onur's
ear-check (research flagged the held-note Sol-vs-Mi question). Wrong notes =
teaching the wrong song. Verify before tuning rungs.
