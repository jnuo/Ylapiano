# App Review notes — y la piano v1

Paste into App Store Connect → App Review Information → Notes.

---

**What the app is.** y la piano is a piano-learning game for young children
(ages 5–7), designed to be used together with a parent. Children's songs fall
as blocks onto an on-screen piano; the child taps the matching keys. A mascot
squirrel ("Pim") encourages every attempt.

**Everything runs on-device.**

- The app makes **no network connections** of any kind: no accounts, no
  analytics, no ads, no third-party SDKs, no web content. Airplane mode is a
  fully equivalent experience.
- The privacy label is **Data Not Collected** and is accurate: song progress
  and user-created songs are stored only in local storage on the device.
- The embedded web view on the sheet-music screen renders a **bundled local
  HTML file** (music-notation rendering via a bundled JS library). It cannot
  navigate anywhere.

**No microphone.** The app does not request microphone access (or any other
permission). Earlier internal builds experimented with pitch detection; that
feature was removed before this submission.

**MIDI keyboards (optional).** If a class-compliant USB MIDI keyboard is
connected to the iPad, the app reads key presses from it via CoreMIDI as an
alternative to touch input. This is local hardware input only.

**How to test in 2 minutes.**

1. Launch → short parent-facing onboarding → home screen with song cards.
2. Tap the first song ("Plim Plim") → 3-2-1 count-in → notes fall toward the
   keyboard; tap the highlighted keys (any timing works — the game never
   punishes).
3. Finish the song (or just let it play out) → star result screen with the
   squirrel's reaction. That is the complete loop.

**Device support.** iPad only (landscape gameplay). 4+ age rating; not opted
into the Kids Category.

---

## Pre-submission checklist (internal — do not paste)

- [ ] B5 (#27) merged: mic permission page/copy removed AND
      `NSMicrophoneUsageDescription` deleted from build settings
      (as of 2026-06-11 the string is still present in project.pbxproj —
      the notes above are written for the post-B5 binary).
- [ ] Re-run the no-network greps (see privacy-nutrition-label.md).
- [ ] Privacy URL live: https://www.onurovali.me/ylapiano/privacy ✓ (200, 2026-06-11)
- [ ] Support URL live: https://www.onurovali.me/ylapiano/support ✓ (200, 2026-06-11)
