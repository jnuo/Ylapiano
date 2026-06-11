# App Privacy ("nutrition label") answers — y la piano v1

**Answer to App Store Connect's privacy questionnaire: Data Not Collected.**

## The one question that matters

> "Do you or your third-party partners collect data from this app?"

**Answer: No.**

That single "No" produces the **"Data Not Collected"** label on the product
page. No per-category questions follow.

## Evidence this is truthful (B18 sub-task 2 gate, run 2026-06-11)

- `grep -riE "http|analytics|track" Ylapiano --include="*.swift"` → only two
  innocuous hits: a code comment ("Tracks which voice…") and SwiftUI
  `.tracking(1.5)` letter-spacing. No URLs.
- `grep -rE "URLSession|URLRequest|Network\.|CFNetwork" Ylapiano` → zero hits.
  The app makes no network connections at all.
- No third-party SDKs besides `swift-midi-io` (local CoreMIDI wrapper, no
  networking).
- No accounts, no sign-in, no IDFA, no receipts validation, no push.
- All persistence is local SwiftData (`default.store` in the app container).

## Re-verify before every submission

Re-run the greps above whenever a new dependency or feature lands. If ANY
networking or analytics is ever added, this label must be redone BEFORE the
build is submitted — a false "Data Not Collected" label is an App Review
rejection and a trust break.

## Related

- Privacy policy URL (App Store Connect field): https://www.onurovali.me/ylapiano/privacy
- Support URL: https://www.onurovali.me/ylapiano/support
