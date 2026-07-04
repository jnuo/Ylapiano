# Store listing — en-US (B19, #29)

Every ASC text field for the en-US storefront. Char limits are enforced by
`scripts/check_store_listing.py` (run it after ANY edit here). Positioning per
the 2026-07-04 committee (#44): song NAMES lead, trust stack always, no
"only/first" exclusivity claims anywhere. The EN hook is the Catalan + Turkish
catalog — that's what an EN-storefront parent searching "Sol Solet piano" or
"Kırmızı Balık piano" cannot find elsewhere easily, and we say it without
claiming nobody else has it.

### FIELD: name · limit 30

```text
Ylapiano: Kids Piano Songs
```

26/30. "Ylapiano" (brand) + function ("Kids Piano Songs" — the three
highest-value EN tokens we can own in the heaviest-weighted field).

**Alternatives if the name is taken in ASC** (App Store names are unique;
verify at app-record creation — "Ylapiano" is coined, collision risk is low):

1. `Ylapiano – Piano for Kids` (25)
2. `Ylapiano: My Piano Songs` (24)
3. `Ylapiano Kids Piano` (19)

**Known mismatch to resolve:** the on-device display name is currently
`y la piano` (`INFOPLIST_KEY_CFBundleDisplayName`, project.pbxproj), while
in-app strings and the whole repo brand say "Ylapiano". Apple prefers the
store name and under-icon name to be recognizably the same (2.3.7 metadata
hygiene). Recommendation: change the display name to `Ylapiano` before
submission, or knowingly keep `y la piano` as the under-icon stylization —
Onur's call, flagged in the PR.

### FIELD: subtitle · limit 30

```text
Play alone. No ads, offline.
```

28/30. The differentiator stack in one line: kid-solo ("play alone") + the
two trust items parents scan for. "Real piano sound" lost the subtitle
bake-off — it's carried by screenshot frame 2 and the description's first
section instead. No token repeats the name (gate-checked).

### FIELD: keywords · limit 100

```text
toddler,preschool,music,keyboard,nursery,rhymes,learn,children,twinkle,catalan,turkish,baby,keys
```

96/100. Single words only — Apple combines keywords into phrases, so
"nursery,rhymes" covers "nursery rhymes" without wasting a space char. No
duplicates of name/subtitle tokens (kids/piano/songs/play/alone/ads/offline
are already indexed from those fields). `catalan,turkish` + `twinkle` carry
the song-search angle; the full song names live in the description (not
indexed, but that's where a parent's eyes confirm the match).

### FIELD: promotional-text · limit 170

```text
13 songs your kid already knows — in Catalan, Turkish and English — on a piano that never says "wrong". Pay once. No ads, no accounts, works offline.
```

149/170. Launch version; editable anytime without review, so this is the
slot for later seasonal pushes (back-to-school, new songs).

### FIELD: description · limit 4000

```text
Sol Solet. Cargol treu banya. Kırmızı Balık. Old MacDonald. If your family sings in more than one language, your kid finally gets a piano game with the songs they actually know — in Catalan, Turkish and English.

Ylapiano is a no-fail piano game for young children on iPad. Songs fall as big colorful blocks toward a piano; your kid taps the matching keys and hears a real recorded piano. Every tap makes music. There is no losing, no red X, no "try again" — a wrong note simply sounds, and the song keeps going.

MADE TO BE PLAYED ALONE
No reading required. Your kid picks a song by its picture, Pim the squirrel counts them in, and the falling notes light the way to the right keys. When the song ends, Pim celebrates, stars appear, and the next song is one tap away. You can hand over the iPad and just listen from the kitchen.

THE SONGS — ALL 13
Catalan: Plim Plim (Salta l'Esquirol), Sol Solet, Cargol treu banya, La lluna la pruna, El lleó no em fa por.
Turkish: Kırmızı Balık, Ali Baba'nın Çiftliği, Mini Mini Bir Kuş, Portakalı Soydum.
English: Old MacDonald, Twinkle Twinkle Little Star, Wheels on the Bus, Itsy Bitsy Spider.
Traditional children's songs — the ones grandparents sing too. Some even cross languages: Old MacDonald and Ali Baba'nın Çiftliği are the same melody, and your kid will notice.

THE QUIET PARTS, OUT LOUD
- Pay once. No subscription, no ads, no in-app purchases.
- No account, no sign-in, no microphone.
- No data collected — the privacy label says exactly that, and it is accurate.
- Works fully offline. Airplane mode changes nothing.

REAL PIANO, TWO WAYS
Every key plays a sampled acoustic piano — recorded from a real upright, not a toy synth.
- On-screen keys sized for small fingers, or
- plug a USB MIDI keyboard into the iPad and the same songs play on real keys.

PROGRESS YOU CAN SEE
Stars are earned per song and saved on the device. The featured song, Plim Plim, climbs a gentle mastery ladder that grows with your kid. A Grown-Ups corner — opened with a long press little fingers won't trigger — holds setup help, support, and a simple editor where grown-ups can add their own songs.

Made by a dad for his own daughter, and built the way he wants apps for his kid to be: no ads, no tricks, nothing to unlock.

Designed for iPad (landscape).
```

2,290/4000. Deliberately short of the cap — parents skim, and every section
carries one job: hook (song names), kid-solo loop, trust stack, catalog,
piano credibility, progress/what's-inside, dad story, device expectation.

### FIELD: whats-new · limit 4000

```text
Ylapiano's first version.

13 traditional children's songs in Catalan, Turkish and English, falling-note gameplay that never punishes, a real sampled piano sound, stars to earn, and a squirrel named Pim who celebrates every attempt.

No ads, no subscription, no account, no data collected. Works offline. Plays on-screen or with a USB MIDI keyboard.
```

349/4000.

### FIELD: captions · limit 2000

```text
1 falling-notes hero | Songs they know, played alone
2 play-on-your-piano | Works with your USB piano
3 pim-celebration | Pim cheers every single try
4 library-with-stars | Stars grow, song by song
5 trust-frame | No ads. No subscriptions. No data.
```

Screenshot headlines for B21's 5-frame arc (#23: hero → USB piano → Pim →
library/progress → trust). ≤6 words each (gate-checked). Frame 5's line is
the literal trust-frame copy from the arc spec.

## Non-text ASC fields (en-US / app-level)

| Field                 | Value                                                                                                                                                                       |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Support URL           | https://www.onurovali.me/ylapiano/support (live, 200 — checked 2026-07-05)                                                                                                  |
| Marketing URL         | https://www.onurovali.me/ylapiano (live, 200 — checked 2026-07-05)                                                                                                          |
| Privacy Policy URL    | https://www.onurovali.me/ylapiano/privacy (live, 200 — checked 2026-07-05)                                                                                                  |
| Copyright             | © 2026 Onur Ovalı                                                                                                                                                           |
| Price                 | €3.99 one-time (committee 2026-07-04, #44 decision 6 — was €0.99; pick the matching tier in ASC; NEVER written inside description/promo text, prices differ per storefront) |
| Age rating            | 4+, standard questionnaire, NOT Kids Category (`product/decisions/2026-06-11-age-rating-4plus.md`)                                                                          |
| Privacy label         | **Data Not Collected** — single "No" to the collection question (`product/store-listing/privacy-nutrition-label.md`; re-run its greps before submission)                    |
| Category (suggestion) | Primary: Education · Secondary: Music — confirm with Onur at app-record creation                                                                                            |
| Review notes          | `product/store-listing/app-review-notes.md`                                                                                                                                 |
