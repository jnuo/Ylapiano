# Juice Spec — Hit Feedback (falling-notes slice)

**Date:** 2026-06-08
**Owner:** Diego (motion)
**Builds on:** `2026-06-08-hit-event-spec.md` (Defne) + `2026-06-08-gamify-juice-slice-tech.md` (Marco)
**Target:** iPad, **60Hz / 17ms frame**, A13 floor. SpriteKit (`FallingNotesScene`) + SwiftUI key squash.
**No character / no Spine / no Aiko dependency** — procedural juice on shapes.

## Canvas (current `FallingNotesScene`)

Coral rounded rects fall down a cream lane → deep-coral hit line at y≈0 (bottom)
→ keys (SwiftUI `PianoKeyboardView`) directly below. Today: no feedback at all.

## Global rules

- **Fire on press. 0 anticipation gating** (Cooper/Medeiros — wind-up plays WITH
  action, never before). Input→pixel <50ms.
- **Hit-pause always AFTER the action starts**, never before.
- **No screen shake, no camera punch, no full-screen flash** (cut the loud half
  of Vlambeer for 5–7).
- **Colorblind-safe by construction:** hit vs miss = presence-of-party + motion-
  toward vs fade-away — NOT hue.

## HIT — right key, ±600ms (default)

| Element       | Spec                                                                   |
| ------------- | ---------------------------------------------------------------------- |
| Note squash   | 0.8×V / 1.15×H over **70ms** (volume-preserving)                       |
| Note pop      | scale 1.0→1.3 + alpha 1→0 over **150ms**, overshoot ease               |
| Hit-pause     | **45ms** on note at squash peak (freeze note only; particles continue) |
| Particles     | **6–8** coral/gold, life 300ms, ~30pt radius, at hit line in that lane |
| Key (SwiftUI) | squash 1.0→0.92→1.0 overshoot + warm glow                              |
| Hit line      | +2pt brighter for **80ms**, that lane only                             |

## PERFECT — right key, ±250ms (same language, louder)

- Particles **10–12** + gold sparkles. Pop scale **1.0→1.4**.
- Add expanding ring: scale 0→1.5, alpha 0.5→0 over **200ms** at hit point.
- Brighter key glow. Same timing + hit-pause as HIT.

## MISS — wrong key, or note passes (soft, never punished)

- Unstruck note: fade 1→0.25, desaturate coral→gray, drift down + shrink→0.9
  over **250ms**. No red X, no buzzer, no shake.
- Wrong-key tap: still SOUNDS (honest piano) + normal small press-squash, but
  **no celebration particles.** Absence of party = the feedback.
- Combo: stops escalating, resets quietly. No "combo lost" drama.

## Combo (bounded escalation)

Escalate particle density + warmth only. 1–2 base · 3–5 +2 particles · 6–9 gold
sparkles + soft key-row shimmer · **10+ hard cap (~14 particles).** Never shake,
never a strobe.

## Accessibility — day one, not v1.1

- `@Environment(\.accessibilityReduceMotion)` branch: pop→scale-only/crossfade,
  particles→0–2 or single opacity bloom, ring→static fade, shimmer off, keep
  (shortened) hit-pause.
- **WCAG 2.3.1: ≤3 flashes/sec, ever.** Max combo = one bounded pulse, not
  repeating flashes. Apple §1.3 reject ceiling for kids (practitioner-observed).

## "No idle, no soul" flag (not a blocker)

No character → lane is lifeless between notes. Slice-cheap fix: breathing hit
line, scale 1.0→1.02 over 1.5s ease-in-out loop. Real hero character + idle =
Aiko's lane, later slice.

## Perf note for Marco

`SKShapeNode` is pricier than `SKSpriteNode` for the ring + particle churn. If
profiling on the A13 shows shape-node cost, swap ring/particles to a small
pre-baked sprite/emitter. Fill-rate is the budget, not particle count. Max ~3–4
notes in window at the slow test tempo — trivial for A13.

## Open questions

- **Khalid:** the hit chime must land at the **pop peak (~70ms after press)**,
  rise in pitch with combo. Sound is half this juice.
- **Defne:** is the combo shown as a _visual_ (growing stack), given "no numeric
  score" + 5yos don't read numbers? Her call on the representation.
