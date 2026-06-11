# YLaPiano — board config (read by the global `jpm-next` skill)

`/jpm-next` reads this to run the next task. YLaPiano has a fully pre-prioritized board → **Drive mode** by default.

## Board

- **GitHub Project:** owner `jnuo`, project **#4** — https://github.com/users/jnuo/projects/4
- **Repo:** `jnuo/Ylapiano` (iOS, SwiftUI, `Ylapiano.xcodeproj`)
- **Statuses (workflow):** Todo → In Progress → In Review → Done
- **Phase order (Milestone):** P0 — Gate + prep → P1 — Songs & foundations → P2 — Onboarding & kid-safe player → P3 — Design & Turkish → P4 — Playtest, screenshots, submit → vNext
- **Priority (label):** `tier:NOW` (red) > `tier:NEXT` (yellow) > `tier:LATER` (gray)
- **Owner (field):** `Persona` (also `lane:*` labels — code / art / writing / onur-device / calendar)

## Verify method

**iOS Simulator** — device **iPad Pro 13-inch (M4)** (app is iPad-only, `TARGETED_DEVICE_FAMILY=2`).
`xcrun simctl boot` → `status_bar override --time 9:41 --batteryLevel 100` → build+install+launch → stills via `simctl io booted screenshot --type=jpeg` (.jpg), video via `recordVideo` (.mov, raw — smoothest). Deliver both to `~/Downloads/` for Onur's review; convert to gif/png only for GitHub issue/PR embeds.

## Persona → skill map

| Persona on the card           | Skill to invoke (the lens)                                           |
| ----------------------------- | -------------------------------------------------------------------- |
| Marco · Tech Lead             | `game-programmer-marco`                                              |
| Defne · Designer              | `game-designer-defne`                                                |
| Aiko · Art Director           | `game-artist-aiko` (+ `jpm-images` / OpenArt to generate)            |
| Diego · Animator              | `game-animator-diego`                                                |
| Khalid · Sound                | `game-sound-khalid`                                                  |
| Mei · Player Research         | `game-playtester-mei`                                                |
| Anya · Producer               | `game-producer-anya` (DEFAULT when ownership is unclear — re-routes) |
| Luca · Marketing              | `game-marketing-luca`                                                |
| jpm-aso · Store               | `jpm-aso`                                                            |
| add-song · Catalog            | `add-song`                                                           |
| appstore-screenshots · Frames | `jpm-appstore-screenshots`                                           |
| Onur · Founder                | human — do all AI-doable prep, then hand off                         |

## Build order (dependency-safe) + dependency map

`B1(#11) → B2(#12) · B3(#13) · B6(#14) → B4(#21)` · `B5(#27) → B8(#15) · B10(#22) · B11(#16)` · `B9(#28) → B13(#18)` · `B20(#20) → B19(#29) → B21(#23)` · `B22(#24)` last. Parallel prep: `B7(#25)`, `B18(#26)`.

**depends_on:** B2←B1 · B4←B2,B3 · B8←B6,B7 · B11←B6 · B9←B1,B3,B7 · B13←B1 · B19←B18 · B21←B9,B19,B20 · B22←B8,B10 · B12←B7 · B14←B2 · B15←B6 · B16←B7. (Also stated in each issue body.)

## Notes

- Each issue body carries a **🔢 Sub-tasks** checklist where every step ends at a **test gate** (XCTest unit / on-device check / upgrade-path test). That checklist is the contract — no scope beyond it.
- Locked decisions: mic stripped for v1, final 13-song list, Kids Category = NO — see `product/decisions/` and `product/roadmap.md`.
- The full loop the skill runs is the generic one in `~/.claude/skills/jpm-next/SKILL.md`.
