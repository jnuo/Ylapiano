---
name: pim-reward-assets
description: Generate Pim's end-of-song reward assets — 3 tier result poses (1/2/3 star) as stills, plus ~2s feedback videos that animate Pim's reaction — from the LOCKED OpenArt "Pim" character, then wire them into the result screen. Use when the user wants to create/refresh the result-screen mascot art, the win/celebration animation, the per-tier Pim poses, or the reward videos. Driven through OpenArt (user-driven tool); this skill produces the exact prompts, consistency rules, export settings, and app wiring.
---

# Pim reward assets (result-screen poses + feedback videos)

End-of-song reward: Pim reacts to how the kid did. Three tiers, each a still
pose **and** a ~2-second video. Output drops into `SongResultView` in
`Ylapiano/Views/PlayerScreen.swift`.

Pim is an **existing, locked character** — a saved Character in OpenArt (warm,
bouncy, patient forest squirrel who plays piano; cheers on a hit, waves "again"
on a miss, **never scolds**). **Canon look = CHIBI** (locked in B7, 2026-06-11):
bright orange fur, cream belly patch, oversized head, big sparkly brown eyes,
rosy blush cheeks, thick clean outlines, flat colors with soft cel shading —
the look of the app icon, the MascotGreeting/Pointing/Cheer stills, and the
PimResult videos. The old painterly squirrel is retired. We are **posing and
animating a locked character**, not designing one. (Static character identity
is Aiko's lane; motion + reduced-motion is Diego's; this skill is the
production pipeline.)

## The consistency contract — the thing that makes or breaks this

Three separately-generated tiers WILL drift (face, proportions, palette) unless
forced. Every generation must:

1. **Seed from the SAME saved Pim Character in OpenArt** — use the Character
   feature, never a fresh from-scratch prompt.
2. **Identical style tokens** every time: same one-line style suffix (below),
   same palette, same line weight, same soft painterly children's-book finish.
3. **Identical framing**: full body, centered, square (1:1), same crop and scale,
   same eye-line to viewer, same flat lighting. Pim should sit in the same spot
   in all three frames so only the _reaction_ changes.
4. **Generate ONE neutral Pim frame first** and reuse it as the **start frame**
   for all three videos — so the clips share an origin and only diverge in the
   reaction.
5. **Compare against the app icon** after generating. If Pim drifts from canon,
   regenerate — don't ship a squirrel that doesn't match the icon. (If the drift
   is unfixable, that's an Aiko re-anchor decision: re-anchor Pim to canon, or
   update the icon to match Pim — flag it, don't silently ship.)

Shared **style suffix** to paste into every prompt:

> `clean 2D cartoon chibi style, bold flat colors with soft cel shading, bright orange fur, cream belly patch, big sparkly brown eyes, rosy blush cheeks, thick clean outlines, full body centered, square 1:1 composition, plain solid pale gray background`

## The three tiers (motion brief — Diego)

Pim is never sad. The 1-star is _encouraging_, not disappointed.

| Tier | Result       | Still pose                                                     | 2s video motion                                               |
| ---- | ------------ | -------------------------------------------------------------- | ------------------------------------------------------------- |
| 1★   | "keep going" | one paw raised in a friendly wave, warm smile, small head-tilt | neutral → raises paw, waves gently, one small nod; soft, calm |
| 2★   | "nice!"      | clapping both paws, ears perked, bright eyes, mid-small-bounce | neutral → claps + one happy bounce on the spot, ears perk     |
| 3★   | "mastered!"  | both arms up celebrating, huge grin, tiny stars around         | neutral → jumps up, arms raised, cheer, sparkle burst, lands  |

## Step 1 — generate the 4 stills in OpenArt

Use the saved Pim Character. One neutral + three tiers. Prompts (append the style
suffix to each):

- **Neutral (start frame, used for all videos):**
  `Pim the squirrel sitting upright beside a small piano, calm neutral expression, looking up toward the viewer expectantly, paws resting`
- **1★:**
  `Pim the squirrel giving a warm encouraging wave, one paw raised, gentle smile, slight friendly head tilt, looking at the viewer`
- **2★:**
  `Pim the squirrel clapping both paws together in a happy little bounce, ears perked up, eyes bright and excited`
- **3★:**
  `Pim the squirrel jumping with both arms raised high in joyful celebration, huge happy grin, sparkles and tiny stars around, mid-air`

Then in OpenArt: **remove background → transparent PNG**, export **square 1:1**
(1024×1024 is plenty; the result card renders ~170pt).

## Step 2 — generate the three ~2s videos in OpenArt

Use OpenArt's image-to-video / start-end-frame (Kling-style):

- **Start frame:** the neutral still (same for all three).
- **End frame:** that tier's still.
- **Duration:** ~2s. Ease in, settle, hold (no dead freeze). Keep motion small
  for 1★/2★, bigger for 3★.
- **Motion prompt:** the "2s video motion" cell from the table above.

Keep them loop-friendly or holding cleanly on the last frame (the result card
stays up). Mute / no baked-in audio — reward sound is Khalid's lane, layered in-app.

## Step 3 — drop into the app

Naming (so they wire with zero guesswork):

- **Stills →** `Assets.xcassets`: `PimResult1`, `PimResult2`, `PimResult3`
  (also serve as the **reduced-motion fallback** and the pre-video placeholder).
- **Videos →** app bundle resources: `PimResult1.mp4`, `PimResult2.mp4`,
  `PimResult3.mp4`.

`SongResultView` playback order (graceful degradation — works at every stage):

1. If the tier `.mp4` exists **and** Reduce Motion is OFF → play it (AVPlayer,
   gentle loop / hold last frame).
2. Else if the tier still (`PimResult<n>`) exists → show it.
3. Else → the current `Mascot` PNG (today's behavior — zero regression).

The AVPlayer seam in `SongResultView` is the wiring point. If it isn't built yet,
that's the one code task this skill hands to Marco/Claude — until then stills
alone already upgrade the screen.

## Hold these

- **Reduced motion is a real branch, not a promise (Diego).** Reduce Motion ON →
  show the still, never the video. Build that path, don't retrofit it.
- **Frame consistency is the IP/quality risk with AI character video** — it's why
  the contract above is step one, not a footnote.
- **Producing ≠ shipping (Anya).** This skill produces the assets. They go live
  in the reward only once the one-song loop is proven fun (the current gate).
  Generate now if you want them ready; don't let it pull focus from the loop.
- **OpenArt is a user-driven tool.** This skill hands exact prompts/steps; Onur
  runs them in OpenArt (logged in, ~3900 credits), or Claude drives the browser
  on request. Seedream-class model for stills, Kling for video.
