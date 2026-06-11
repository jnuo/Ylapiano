# YLaPiano board — how to read & track it

**Board:** https://github.com/users/jnuo/projects/4 ("YLaPiano")
**Issues:** https://github.com/jnuo/Ylapiano/issues · **Milestones:** /milestones

## Methodology: Sequenced Kanban

One system, four axes — all already on every card, no extra fields to maintain:

| Axis                 | Where                       | Values                                                                             |
| -------------------- | --------------------------- | ---------------------------------------------------------------------------------- |
| **Workflow**         | `Status` column (kanban)    | 📋 Todo → 🔨 In Progress → 👀 In Review → ✅ Done                                  |
| **Phase**            | `Milestone`                 | P0 → P1 → P2 → P3 → P4 → vNext                                                     |
| **Priority**         | `tier:` label (colored)     | 🔴 NOW · 🟡 NEXT · ⚪ LATER                                                        |
| **Owner / lane**     | `lane:` label               | code · art · writing · onur-device · calendar                                      |
| **Sequence + tests** | checklist inside each issue | numbered sub-tasks, each ending at a **test gate**; card shows progress (e.g. 4/7) |

## Two board views to flip between

1. **"By Phase"** — group by `Milestone`. Swimlanes = the roadmap (P0→vNext). Use to see the plan.
2. **"Workflow"** — group by `Status`. Use day-to-day: drag a card Todo → In Progress → Done.

To set a view: open the board → view tab → **Group by** → pick `Milestone` or `Status`. To focus on what's next: **Filter** `label:tier:NOW`.

## How sub-tasks work

Each issue's body has a **🔢 Sub-tasks** checklist — the sequential build order, where **every step names its test** (XCTest unit, on-device check, or upgrade-path test). Tick them as you go; the % shows on the card. The hard ones (B1 upgrade test, B22 playtest) are the kill-criteria gates from the roadmap.

NEXT / LATER issues are intentionally left coarse — decompose them only when promoted to NOW (don't over-plan deferred work).

## Priority / build order (NOW tier, dependency-safe)

P0 (done/prep): **B7** art · **B18** compliance — gate ✅ passed
P1: **B1** → **B2**, **B3**, **B6** → **B4**
P2: **B5** → **B8** · **B10** · **B11**
P3: **B9** → **B13**
P4: **B20** → **B19** → **B21** · **B22** (recruit now, runs last)

Full backlog + RICE: `product/roadmap.md`. Song list: `product/decisions/2026-06-10-song-list.md`.
