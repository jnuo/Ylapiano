# B19 store listing pack (#29)

`en-US.md` + `tr.md` hold every App Store Connect text field, char-counted.
Gate: `python3 scripts/check_store_listing.py` — limits, cross-field dedup
(name/subtitle/keywords share one keyword pool), keyword hygiene, caption
word counts. Run it after any edit; it must exit 0 before submission.

## Claims audit — every factual statement, sourced

No claim in either locale is invented. Verify each row again before the
actual submission (especially if any card lands between B19 and submit).

| Claim in copy                                                          | Source of truth                                                                                                                                                                                 |
| ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 13 songs; the exact song names; 5 Catalan / 4 Turkish / 4 English      | `product/decisions/2026-06-10-song-list.md`; B2 catalog merged (commit 5ba4f72)                                                                                                                 |
| Old MacDonald = Ali Baba'nın Çiftliği (same melody)                    | same decision doc, "Cross-language pairs"                                                                                                                                                       |
| No-fail play, wrong note never punishes                                | B4 uniform game mode (#21); `app-review-notes.md` "any timing works — the game never punishes"                                                                                                  |
| Kid picks songs by picture, no reading                                 | B9 picture icons (#28)                                                                                                                                                                          |
| Pim the squirrel, count-in, celebration, stars on result               | B31/B27/B11, B4 stars/Pim result                                                                                                                                                                |
| Next song one tap away                                                 | B26 next-song handoff card (#37)                                                                                                                                                                |
| Real recorded piano ("recorded from a real upright")                   | `ATTRIBUTIONS.md` — Upright Piano KW SoundFont, sampled from a Kawai upright, CC0 (no credit legally required; credited in-app in the Grown-Ups corner anyway — deliberately NOT in store copy) |
| USB MIDI keyboard works                                                | CoreMIDI input, `app-review-notes.md` "MIDI keyboards (optional)"                                                                                                                               |
| Pay once, no subscription, no in-app purchases                         | paid-upfront app, no StoreKit purchase code in repo                                                                                                                                             |
| No account, no sign-in, no microphone                                  | B5 mic deletion (#27, commit a6f69c2); no auth anywhere                                                                                                                                         |
| No data collected + label accuracy                                     | `product/store-listing/privacy-nutrition-label.md` (re-run its greps pre-submit)                                                                                                                |
| Works fully offline / airplane mode                                    | privacy label evidence: zero network APIs in codebase                                                                                                                                           |
| Stars saved on device                                                  | B3 persist bestStars/bestRung (#13), local SwiftData                                                                                                                                            |
| Plim Plim mastery ladder, kid decides when to climb                    | B4 (ladder gated to Plim Plim); in-app string in `Localizable.xcstrings`                                                                                                                        |
| Grown-Ups corner behind a long press; setup help, support, song editor | B17 (#7) — 2.5 s hold gate; AddSongScreen is local-only                                                                                                                                         |
| Made by a dad for his own daughter                                     | `product/store-config.md` ("built for Deniz")                                                                                                                                                   |
| iPad only, landscape                                                   | `product/decisions/2026-06-11-kids-category-no-ipad-only.md`                                                                                                                                    |

Deliberately ABSENT from the copy (no false/risky claims):

- No "only/first/best" exclusivity anywhere (committee #44).
- No price number in description/promo (differs per storefront; "pay once"
  carries the trust point).
- No "learn to read music" / educational-outcome promises.
- No age range number (docs vary 4–6 vs 5–7; the 4+ rating plus "young
  children" is what we can stand behind).
- No "hears your piano" — the mic is deleted (B5); input is touch or USB
  MIDI only.

## Open items for Onur (also in the PR)

1. **Name availability** — check `Ylapiano: Kids Piano Songs` /
   `Ylapiano: Çocuk Piyano Oyunu` when creating the ASC app record;
   alternates listed per locale.
2. **Display-name mismatch** — under-icon name is `y la piano`
   (project.pbxproj) vs store brand "Ylapiano". Align or accept (see
   en-US.md).
3. **Price tier** — confirm the ASC tier that maps to €3.99 (committee #44
   decision 6). TR storefront stays live at the symbolic tier ASC derives.
4. **Category** — suggestion Education (primary) + Music (secondary);
   confirm at record creation.
