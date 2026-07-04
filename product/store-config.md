# YLapiano — Store Config

Per-app config read by the global `jpm-appstore-release` and `jpm-appstore-screenshots` skills.
YLapiano is a **native iOS app** (SwiftUI, `Ylapiano.xcodeproj`) — gamified piano learning, built for Deniz. First solo paid App Store launch (€3.99 one-time paid).

## Platforms & store

- **iOS only.** No Android. Skip every Play Console / AAB step in the release skill.
- **Bundle ID:** `com.ylapiano.app`
- **Pricing:** €3.99 one-time paid (committee 2026-07-04, #44 decision 6; tier set in App Store Connect). TR storefront stays live at the symbolic tier ASC derives — no TR ASO investment.
- **Launch geo:** Turkey + non-EU first; **EU added now that DSA trader verification is live** (approved 2026-06-09).
- **Age / category:** standard **4+**, NOT the Apple Kids Category, and **iPad-only** (`TARGETED_DEVICE_FAMILY = 2`) — both LOCKED in `product/decisions/2026-06-11-kids-category-no-ipad-only.md`.

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

- **iPad-only.** The app is `TARGETED_DEVICE_FAMILY = 2` on every target/config (decision: `product/decisions/2026-06-11-kids-category-no-ipad-only.md`), so the App Store needs exactly ONE screenshot size: **iPad 13" `2048×2732`** (verify the current required size at submission time). There is NO phone screenshot set — do not add one.
- **Render source: iOS Simulator (`simctl`)** — native app, NOT Playwright.
  - Device: iPad Pro 13-inch (M4) simulator.
  - Clean status bar: `xcrun simctl status_bar booted override --time "9:41" --batteryLevel 100 --cellularBars 4`.
  - Capture: the **`StoreScreenshotsUITests` harness** (`XCUIScreen.main.screenshot()`) — it drives the seed mechanism below and writes PNGs. Ad-hoc: `xcrun simctl io booted screenshot out.png`.
  - **Seed mechanism (B20 #20): `-screenshotState <profile>` launch argument.**
    - Profiles: `home` (library grid with the designed 3/2/1/0 star spread), `playing` (frozen mid-play falling-notes moment — clock frozen, Pause chrome up, no count-in), `result` (3-star result + handoff card; legacy `-b26-demo-result-stars N` picks another tier).
    - Determinism: while a profile is active, Pim's home idle renders the static still and the result screen's looping reward clip renders the static pose — every seeded state is pixel-stable.
    - Turkish variants: add `-AppleLanguages (tr) -AppleLocale tr_TR`. Always pass `-hasCompletedOnboarding YES` too (skips onboarding + the 4 s intro).
    - Guarding: compiled under `DEBUG || STORE_CAPTURE` only — Release/App Store builds ignore the argument. If device shots ever need a release-config build, build with `SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) STORE_CAPTURE`; never weaken the DEBUG guard.
    - Run the harness:
      ```
      xcodebuild test -project Ylapiano.xcodeproj -scheme Ylapiano \
        -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M4)' \
        -only-testing:YlapianoUITests/StoreScreenshotsUITests \
        TEST_RUNNER_B20_SEED_SCREENSHOTS=1 \
        TEST_RUNNER_B20_SEED_SCREENSHOT_DIR=$HOME/Downloads/ylapiano-b20-seeds
      ```
      (`TEST_RUNNER_<VAR>` is how a variable reaches the simulator test-runner process; a plain shell export never arrives.)
- **Canva designs: TODO (not created yet).** When you build the first set, create the V2-workflow designs in a Canva folder named **"YLapiano App Store Images"** and record per-design IDs here (live + last V2), matching the Salta config's format.
- **Frame arc (B21 #23):** falling-notes hero → play-on-your-piano → Pim celebration → library-with-stars → trust frame ("no ads · no subscriptions · no data collected"). tr + en-US. Shoot LAST, from the B20 seeded states.
- **Output paths:** renders → `tmp/screenshots/raw-{locale}/`; final exports → `product/store-listing/screenshots/{locale}/`.

## Open items before first store submission

- [x] Confirm Kids Category yes/no — **NO**, standard 4+ (`product/decisions/2026-06-11-kids-category-no-ipad-only.md`).
- [ ] Decide v1 song count (1 vs 2-3) — product call, not a config value.
- [x] Document the simulator seed mechanism for screenshot frames — B20 `-screenshotState`, above.
- [ ] Create Canva designs + fill the design IDs / frame arc above (B21 #23).
