# YLapiano — Store Config

Per-app config read by the global `jpm-appstore-release` and `jpm-appstore-screenshots` skills.
YLapiano is a **native iOS app** (SwiftUI, `Ylapiano.xcodeproj`) — gamified piano learning, built for Deniz. First solo paid App Store launch (€1 one-time paid).

## Platforms & store

- **iOS only.** No Android. Skip every Play Console / AAB step in the release skill.
- **Bundle ID:** `com.ylapiano.app`
- **Pricing:** €1 one-time paid (Tier set in App Store Connect).
- **Launch geo:** Turkey + non-EU first; **EU added now that DSA trader verification is live** (approved 2026-06-09).
- **Age / category:** built for a toddler — verify whether it's filed under the **Apple Kids Category**. If yes, Kids Category rules apply (parental gate, no third-party analytics/ads, stricter privacy). Confirm before filling the privacy questionnaire.

## Locales

- `tr` (primary — Onur's home market) and `en-US`.
- TR runs ~20-30% longer than EN; trim to fit char limits.
- Copy approach: **solo pass** (no committee — a €1 single-song app doesn't warrant Salta's multi-persona copy review). Write TR natively ("sen"), no calques, no emoji.

## Release (for `jpm-appstore-release`)

- **version.json:** repo root (currently `1.4.6` / build 6).
- **Changelog:** `product/releases/RELEASES.md`.
- **Release log / dated files:** `product/releases/` — create `APPSTORE.md` (live-version log, newest first) on first store release; dated file `product/releases/{YYYY-MM-DD}-v{version}.md`.
- App Store "What's New" ≤4000 chars per locale. (No Play notes — iOS only.)

## Screenshots (for `jpm-appstore-screenshots`)

- **Render source: iOS Simulator (`simctl`)** — native app, NOT Playwright.
  - Devices: iPhone 6.7" (e.g. iPhone 15 Pro Max) for `1290×2796`; iPad 12.9" for `2048×2732` (verify current required App Store sizes at submission time).
  - Clean status bar: `xcrun simctl status_bar booted override --time "9:41" --batteryLevel 100 --cellularBars 4`.
  - Capture: `xcrun simctl io booted screenshot out.png`. Prefer an **Xcode UI test** (`XCUIScreen.main.screenshot()`) if deterministic navigation/seeding is needed.
  - Seed mechanism: **TODO** — document how to put the app in the demo state for each frame (debug menu? launch arg? a seeded build?).
- **Canva designs: TODO (not created yet).** When you build the first set, create the V2-workflow designs in a Canva folder named **"YLapiano App Store Images"** and record per-design IDs here (live + last V2), matching the Salta config's format.
- **Frame arc: TODO.** Decide what each frame sells. Given the thin v1 (single song, no onboarding), candidates: hero (the song playing with falling notes / piano keys lit) → the reward/celebration moment → progress/stars → parent value (learn-by-play). Keep it short (3-5 frames); don't pad.
- **Output paths:** renders → `tmp/screenshots/raw-{locale}/`; final exports → `product/store-listing/screenshots/{locale}/`.

## Open items before first store submission

- [ ] Confirm Kids Category yes/no (drives privacy + analytics rules).
- [ ] Decide v1 song count (1 vs 2-3) — product call, not a config value.
- [ ] Document the simulator seed mechanism for screenshot frames.
- [ ] Create Canva designs + fill the design IDs / frame arc above.
