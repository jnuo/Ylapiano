# Ylapiano — Locked v1 Spec

## Vision

A no-fail piano learning **game** for kids 4-6 on iPad, where every tap or key
press makes real piano sound, every correct note feels celebratory, and a real
MIDI keyboard (when connected) deepens the experience without ever becoming a
barrier.

## Positioning

Indie premium, **$9.99 one-time**, Family Sharing enabled.
Story: "Made by a dad for his daughter Deniz." Free trial = first song unlocked.

## Audience

Ages 4-6 only. Adult mode and ages 7-8 deferred to v1.2.

## Modes (all three in v1)

- **Practice** — on-screen 2-octave keyboard, tap to play.
- **Play** — real MIDI keyboard (USB-C or Bluetooth), auto-detected.
- **Free Play** — sandbox, no song, character reacts to notes.

Plus the existing **Read Mode** (sheet music via abcjs webview) is preserved
unchanged.

## Repertoire — 6 songs in v1

1. Hot Cross Buns (3 notes, RH)
2. Mary Had a Little Lamb (3 notes, RH)
3. Twinkle Twinkle Little Star (recognition driver)
4. Old MacDonald (recognition driver)
5. Frère Jacques (round)
6. **Deniz's Lullaby** — original composition we own

All public domain except the original. Disney/pop deferred (sync licenses
$5K+/song; not solo-feasible).

## Falling-Notes Mechanic — Numbers

Kid mode (default and only mode in v1):

- Lead time: **4s**
- Scroll: **240 pt/s**
- Hit windows: Perfect ±90ms · Great ±180ms · Good ±260ms · **no miss penalty**
- Audio plays on every input regardless of timing accuracy
- Combo: ×1.0 → ×1.25 (10) → ×1.5 (25) → ×2.0 (50, cap)
- End-screen stars: 1=60% · 2=80% · 3=95% accuracy
- Hint glow on next key 1s before arrival (toggleable)
- Wrong note: yellow hint pop on missed key, no shake, no red, encouraging
  voice line from a 30+ pool, never repeating in a row

## Pedagogy Adds

- Finger numbers (1-5) on each falling note
- Long notes are stretched capsules (rhythm visualization)
- Count-in: "1-2-ready-go" before song starts
- Character hums melody for 4s before notes fall (audiation)

Deferred to v1.1: notation overlay, two-hand mode, "echo me" ear-training
mini-game.

## Visual System

Palette (WCAG AA passing, colorblind-safe with shape coding):

- `#FFF7EC` cream — primary canvas
- `#2B2D42` deep ink — text
- `#D62828` deep coral — RH falling notes (rounded rect shape)
- `#0E8C84` deep teal — LH falling notes (chevron shape)
- `#FFD166` sun yellow — stars, celebrations
- `#A06CD5` royal purple — sharps/flats, premium moments

Type: SF Pro Rounded only. Bold titles, Semibold body, min 18pt body / 28pt
kid instructions. Dynamic Type `.large` to `.accessibility3`.

Character: prototype with a cat (universal, simple to draw). Final design vote
with Deniz when she's old enough. Idle PhaseAnimator blink+breathe every 4-6s.

## Layout

iPad landscape primary, portrait stacked fallback (HIG compliance).
`minimumSize` 1024×768 to dodge Stage Manager compressed UX.

```
[ Top bar 60pt (adaptive) — pause | character | score + stars ]
[ Falling-notes lane (SpriteKit) — ~55% height                ]
[ Piano keyboard (SwiftUI) — ~40%, full-bleed bottom          ]
```

## Animation List (Top 15)

1. Key press — scale 1.0→0.94, spring(0.35, 0.6), light haptic (iPad mini 6+)
2. Correct note hit — `matchedGeometryEffect` morphs falling note → key glow
   - 12-particle burst
3. Note approaching — target key pulses hand-color last 0.3s
4. Streak counter — KeyframeAnimator scale-bump + slight rotation
5. Star earned — `.symbolEffect(.bounce)` + scale+opacity transition
6. Song complete — Lottie confetti overlay (3s) + character celebration loop
7. Character idle — PhaseAnimator blink/breathe loop (essential)
8. Pause/resume — `matchedGeometryEffect` between bar icon and modal
9. Wrong note — gentle 4pt horizontal shake on the wrong key, no color change
10. Level transition — SKTransition.crossFade + title slide-up
11. MIDI connect — top banner slides down, soft chime, character looks up
12. MIDI disconnect — banner fades to yellow, no alarm
13. Combo milestone — screen-edge particle ring at 10/25/50
14. Wait Mode (next note) — pulsing glow on target key + gentle "ding" every
    2s if user pauses
15. End-of-session reward — kid picks 1 of 3 prizes (Khan Kids pattern)

All animations gated behind `@Environment(\.accessibilityReduceMotion)`.

## Audio + MIDI Architecture

- **AVAudioEngine** + **AudioKit `AppleSampler`** (not hand-rolled
  `AVAudioUnitSampler`)
- **MIDIKit** (not hand-rolled CoreMIDI)
- SoundFont: **Salamander C5 Light SF2** (~25 MB, **CC-BY 3.0, must attribute
  Alexander Holm**), bundled in app
- Audio session: `.playback`, `.mixWithOthers`, 5ms preferred buffer, 48 kHz
- Engine starts at app launch, lives entire lifecycle
- MIDI: auto-connect all sources on start, re-scan on `.MIDISetupChange`
- Bluetooth pairing via `CABTMIDICentralViewController`
- Connection state machine: `.none / .scanning / .connected(name) / .lost`
- Master clock: `engine.outputNode.lastRenderTime` (`AVAudioTime`)
- Scroll: `CADisplayLink` reads audio host time each vsync, computes
  `noteY = (noteTime - audioTime) × pixelsPerSecond`
- One-time loopback latency calibration on first launch

## Compliance (App Store blockers — non-negotiable)

- **Kids Category, Ages 4-6 band**
- Math-based parent gate before Settings, IAP (when added in v1.1), external
  links
- COPPA-compliant Privacy Policy
- Zero third-party analytics in v1
- No accounts, all progress local (UserDefaults + Codable)

## Accessibility

- VoiceOver labels on every key (e.g., "C, fourth octave, right hand note")
- `@Environment(\.accessibilityReduceMotion)` gates all animations
- Differentiate Without Color (RH = rounded rect, LH = chevron)
- Dynamic Type `.large` to `.accessibility3`
- Guided Access recommended in onboarding

## Onboarding

3-step ghost-finger pantomime, no text, audio narration only:

1. Finger taps glowing key
2. Note falls
3. Star pops

## Reward Structure

- Stars per song (1=60%, 2=80%, 3=95%)
- **Song mastery map** — 6 song-tiles as a path with character walking it
  (visible progression replaces streaks/currency)
- End-of-session prize: kid picks 1 of 3 (sticker / color / outfit)
- Daily surprise: character delivers a wrapped gift on first open of the day
- No streaks, no currency, no leaderboards, no lives

## Share Moment

End-of-song "celebration card" with kid's name + song name + cute
illustration. Auto-saves to Photos for parent share. Differentiates and adds
virality.

## Voice Lines

ElevenLabs Multilingual v2 (kid voice) for v1. Deniz overlay later. 30+
encouragement clips, never repeat same line in a row.

## Tech Stack — Final Lockdown

- **SwiftUI** + **SpriteKit** (existing ylapiano repo, extended)
- **AudioKit** for `AppleSampler` + SF2 loading
- **MIDIKit** for CoreMIDI input + Bluetooth
- **Salamander C5 Light SF2** with attribution
- **Existing abcjs in webview** preserved for Read Mode

## Sprint Plan — 41 Days

- **Sprint 0 (3d) — De-risking spike** ← starting now
- Sprint 1 (5d) — Audio engine + tap-to-play + 6-song JSON
- Sprint 2 (5d) — MIDIKit + Bluetooth pairing + connection banner
- Sprint 3 (10d) — Falling-notes scene, hit detection, 3 songs playable
- Sprint 4 (5d) — Animation polish (matchedGeometry, character, confetti,
  voice lines, palette)
- Sprint 5 (5d) — Remaining 3 songs + picker + mastery map + share card
- Sprint 6 (3d) — Onboarding pantomime + parent gate + a11y + Settings
- Sprint 7 (5d) — Polish + TestFlight + App Store submission

**Total: 41 days realistic** (~6 weeks evenings/weekends).

## Sprint 0 — De-risking Spike

The single thing that can kill this whole architecture is **audio-visual sync
drift over a 3-minute song**. We prove this works before building anything
else.

- **Day 1** — SwiftUI `SpriteView` + one `SKShapeNode` whose Y is recomputed
  every `update(_:)` from `engine.outputNode.lastRenderTime`. No song, no
  MIDI, no sampler. Prove sync stays locked over 60s.
- **Day 2** — Add MIDIKit + AudioKit `AppleSampler` with Salamander. One
  USB-C MIDI key → sound + visual hit registered. Measure end-to-end latency.
- **Day 3** — Hardcode 30s of Twinkle Twinkle. Play through with screen
  recording + audio waveform. **If drift >20ms at 30s, redesign before week 2.**

## Open Items (resolved)

| Question                                   | Decision                                         |
| ------------------------------------------ | ------------------------------------------------ |
| Adult mode in v1?                          | No — v1.2                                        |
| Notation overlay v1?                       | No — v1.1                                        |
| Profiles?                                  | Single profile, Family Sharing handles multi-kid |
| Voice lines?                               | ElevenLabs v1, Deniz overlay later               |
| Character design?                          | Cat prototype, Deniz votes when older            |
| Two-hand mode?                             | Defer to v1.1                                    |
| Multi-window / Stage Manager full support? | Defer to v1.1                                    |
| Apple Pencil?                              | Defer to v1.1 (Read Mode annotation only)        |

## Deferred to v1.1+

- Notation overlay
- Two-hand mode
- "Echo me" ear-training mini-game
- Apple Pencil annotations
- Multi-window
- Guest characters / costumes
- Adult mode (→ v1.2)
- More songs (Disney/pop pending license)
- "Duet mode" (parent + kid)
- Weekly progress email for parents
