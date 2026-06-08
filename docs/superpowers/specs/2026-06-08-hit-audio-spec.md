# Audio Spec — Hit Feedback (falling-notes slice)

**Date:** 2026-06-08
**Owner:** Khalid (audio)
**Builds on:** hit-event spec (Defne) + hit-juice spec (Diego) + tech lock (Marco)
**Runtime:** native **AVAudioEngine** (not Howler/Phaser). Middleware is Marco's
lane; this spec is the sound design.

## Central principle

The kid is already playing a **real piano note** (`PianoSampler.play`) on a
correct press. That note IS the primary reward. The hit "sparkle" is seasoning
layered UNDER it — and must be harmonically consonant or it sounds wrong on a
piano app.

## HIT — right key, ±600ms

- Soft **celesta / music-box "ting," pitched to the octave ABOVE the played
  note** (consonant by construction).
- **~200ms**, soft attack (no sharp transient), gentle shimmer decay.
- **−9 to −12 dB under the piano note.** Fires at the visual pop peak (~50–70ms
  after press).

## PERFECT — ±250ms

- Same celesta, brighter: add fifth + octave shimmer + short sparkle tail.
- Slightly louder, still under the note. Same timbre, more of it.

## MISS — wrong key, or note passes

- **No added sound.** Wrong key still plays the honest piano note; absence of
  the sparkle IS the feedback. **Never** a buzzer/thud (startle = 1-star + breaks
  the no-punish rule).
- Open question (Defne): ghost-play an unstruck passing note at −12 dB to keep
  the song continuous? Recommend yes (ghost, don't silence).

## Combo — "rises in pitch", refined

- NOT a pitch slide. Step up a **pentatonic scale** — each consecutive hit adds
  the next pentatonic note → a rising melody that can't sound wrong over the
  song (Bawler / Monument Valley tap-as-note-in-key model).
- Cap ceiling at ~one octave (no dog-whistle / fatigue). Reset on miss.

## Governing constraint: the fatigue test

Fires on EVERY note, hundreds/session. Miller (Pok Pok): "calming sounds, heard
a number of times without becoming fatiguing." Short, soft, music-box, low in
mix. This is why it's celesta, not a synth zap.

## Mix targets

- Master **−18 LUFS integrated, true peak ≤−1 dBTP**, narrow loudness range
  (no startle cliff).
- Sparkle peak **≤−12 dBFS**. Piano note is the loudest element.
- **Test on the iPad 9th-gen speaker at low volume, not headphones.** If the
  sparkle vanishes under the note there, rebalance.
- Mind the existing **metronome tock** — keep the sparkle in a brighter bell
  register so they don't mask each other.

## Hardware notes

- **No haptics:** standard iPads have no Taptic Engine. Off the table for the
  iPad-only slice (would be ideal + mute-safe; add if iPhone joins later).
- **Session category `.playback` is defensible here** — this is an instrument
  (like GarageBand); the kid wants to hear the piano even on silent. Tradeoff: a
  parent on silent expecting quiet gets piano. (Already set this way.)

## No music bed

The kid's notes ARE the music. No backing track this slice (play-along track is
a later design call — Defne).

## Production

Synthesize the sparkle in-engine (matches `PianoSampler` additive synth: few
partials, fast attack, shimmer decay), pitched per note. Zero assets, zero
license. Mute-safe by construction — Diego's pop/particles are the redundant
visual cue for any audio.
