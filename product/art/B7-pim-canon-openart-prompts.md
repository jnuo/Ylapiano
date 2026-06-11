# B7 — Pim canon lock: OpenArt session pack

One session, 4 generations, all from the **saved chibi Pim Character** in OpenArt
(the one used for the PimResult videos). Never a from-scratch prompt — always the
Character feature, or consistency dies.

**Canon reference:** bright-orange chibi squirrel — oversized head, big brown
sparkle eyes, blush cheeks, cream belly, thick clean outlines, flat colors with
soft shading. (Frame from PimResult3.mp4 is the anchor; compare every output
against it.)

**Style suffix — paste at the end of EVERY prompt:**

> clean 2D cartoon chibi style, bold flat colors with soft cel shading, bright
> orange fur, cream belly patch, big sparkly brown eyes, rosy blush cheeks,
> thick clean outlines, full body centered, square 1:1

## 1 · App icon (1024×1024, OPAQUE — no transparency in App Store icons)

> Pim the chibi squirrel sitting behind white piano keys at the bottom edge,
> paws on the keys, face front and filling the upper two thirds, joyful open
> smile, warm cream-to-peach gradient background, two tiny music notes floating
>
> - style suffix

- Crop tight: head + keys must read at 60×60. No text, no border.
- Export 1024×1024 PNG, opaque.

## 2 · MascotGreeting (transparent PNG, 1024×1024)

> Pim the chibi squirrel waving hello with one paw raised high, warm open-mouth
> smile, friendly head tilt, other paw resting, standing full body
>
> - style suffix

## 3 · MascotPointing (transparent PNG, 1024×1024)

> Pim the chibi squirrel pointing forward and slightly down with one paw,
> encouraging smile, leaning a little toward the viewer, tail curled up
>
> - style suffix

## 4 · MascotCheer (transparent PNG, 1024×1024)

> Pim the chibi squirrel jumping mid-air with both arms raised in celebration,
> huge happy grin, eyes closed with joy, tiny stars and sparkles around
>
> - style suffix

(Closest existing art: the PimResult3 jump — same energy, but generate fresh so
the still isn't a video frame crop.)

## Export checklist (the sub-task 1 test gate)

- [ ] 4 PNGs, 1024×1024
- [ ] Icon opaque; the 3 mascot stills background-removed → transparent
- [ ] Same character across all 4 (line them up against the PimResult3 frame —
      same eye style, same orange, same outline weight; drift → regenerate)
- [ ] Drop them in `~/Downloads/` as `icon_1024.png`, `MascotGreeting.png`,
      `MascotPointing.png`, `MascotCheer.png` — Claude wires them from there.

## Skipped on purpose

- "Listening" pose — mic is stripped from v1 (locked decision).
