---
name: add-song
description: Turn a real song into a YLapiano playable song — find/transcribe its melody and emit paste-ready Swift (a Song builder for SeedData.swift) that fits the game's constraints. Use when the user wants to add a new song, find the notes for a tune, transcribe a melody for the game, or asks "add <song> to ylapiano". Handles transposition to C major, white-key-only fitting, and the C3–C5 range.
---

# Add a song to YLapiano

Turn a real song into a `Song` the falling-notes game can teach. The output is
**paste-ready Swift** for `Ylapiano/Models/SeedData.swift` — a
`private static func` plus the one-line wiring. Notes must be **correct**: a
wrong note teaches the wrong song (the "Salta l'Esquirol held Sol-vs-Mi" trap is
exactly what this skill exists to avoid).

## The playable envelope — every note MUST fit this

The game only renders white-key lanes over a 2-octave keyboard. A melody that
breaks these isn't "harder," it's **unplayable** — transpose/simplify until it fits.

1. **White keys only.** Solfège is `Do Re Mi Fa Sol La Si` — there are **no
   playable black keys**. Transpose the song to **C major** so every note is a
   natural. Songs in other keys get transposed; songs with chromatic notes get
   the accidental rounded to the nearest scale tone (and flag it).
2. **Range C3 → C5.** Octaves **3, 4, 5 only**; bottom note `Do` octave 3, top
   note `Do` octave 5 (`KeyboardLayout.default` = startOctave 3, octaveCount 2,
   15 white keys). If the tune's range is wider than two octaves, pick the verse
   that fits or fold octave leaps inward. Most kids' melodies sit in octave 4.
3. **Four durations only:** `.whole` (4 beats), `.half` (2), `.quarter` (1),
   `.eighth` (0.5). **No** dotted notes, triplets, sixteenths, or rests.
   Approximate: triplet → two eighths; dotted-quarter → quarter (or quarter+
   eighth); sixteenth runs → eighths. Note every approximation you make.
4. **Melody only.** One voice — the right-hand tune a kid sings. No chords, no
   harmony, no accompaniment.
5. **One phrase, ~16–40 notes.** Match the existing songs (see `plimPlim()` in
   SeedData) — a single recognizable verse/chorus, not the whole song.
6. **Bar-aligns in 2/4.** Songs render in 2/4 (2 beats/bar). Keep phrasing so
   bar groups sum to whole beats; it makes the falling blocks land cleanly.

## Process

1. **Get the song.** Name + origin/language. Ask for a reference if there's any
   doubt which version: a YouTube link, sheet music, or "the one that goes …".
   For Turkish kids' songs, confirm the canonical melody (many share tunes — e.g.
   _Daha Dün Annemizin_ is the Twinkle/ABC melody).
2. **Find the real melody from a reliable source.** Search for sheet music
   (MuseScore, musicnotes), an ABC/MIDI transcription, or a well-known notation.
   **Do not invent notes from memory of how it sounds** — verify against a
   source. If you genuinely can't find one, say so and ask the user to hum/record
   it rather than guessing.
3. **Find the key, transpose to C major.** Map scale degrees → solfège
   (1=Do, 2=Re, 3=Mi, 4=Fa, 5=Sol, 6=La, 7=Si). Pick the octave placement that
   keeps the tune in C3–C5, centered on octave 4.
4. **Simplify rhythm** to the four allowed durations; keep the felt rhythm.
5. **Convert** each note to `NoteEntry(solfege: .X, octave: N, duration: .Y)`.
6. **VERIFY — this is the point of the skill, not a formality:**
   - Check the **contour**: does your sequence rise/fall/repeat where the real
     melody does? Sing it in your head against the source.
   - Check **intervals** at the signature moments (the hook, the cadence).
   - **Flag every note you're under ~90% sure of** — especially long/held notes
     and phrase-ending notes, where transcription errors hide.
   - Hand the result to **Onur for an ear-check** (he plays piano — he's the
     final gate). Give him the solfège line to play, not just the code.
7. **Emit** (see Output).

## Output format

Produce, in this order:

1. **The Swift builder**, matching the house style in SeedData.swift — lyric
   comments above each phrase, e.g.:

   ```swift
   /// <Title> — <origin>. Transposed to C major, 2/4, <bpm> BPM. RH melody only.
   /// Source: <url>. Approximations: <e.g. triplet on "..." → eighth pair>.
   private static func <camelCaseTitle>() -> Song {
       Song(
           title: "<Display Title>",
           bpm: <kid-friendly default, e.g. 80>,
           notes: [
               // "<lyric phrase>"
               NoteEntry(solfege: .Do, octave: 4, duration: .quarter),
               // ...
           ]
       )
   }
   ```

2. **The wiring line** for `createSeedSongs()`, and a note on retired titles if
   the song was previously pruned (see `retiredSeedTitles`).

3. **An "ear-check these" list** — the specific notes/bars you're least sure of,
   so Onur knows exactly what to confirm.

## Two things to hold

- **BPM is a soft default now.** The mastery ladder overrides tempo per rung
  (50→120 BPM). Pick a sensible `bpm` for the song's identity, but don't agonize
  — the rung sets the real playback tempo. See `MasteryLadder` in
  `Ylapiano/ViewModels/PlayerViewModel.swift`.
- **Producing ≠ shipping (scope).** This skill _produces_ the song. Whether it
  goes live in `createSeedSongs()` is a scope call: the current mission is one
  song (Salta l'Esquirol) made great and its loop proven. **By default, output
  the builder but do NOT make it the active song** — leave Salta as the proof
  unless Onur explicitly says to swap or add it to the live list.

## Good first Turkish candidates (simple, white-key-friendly in C)

- **Daha Dün Annemizin** — same melody as Twinkle Twinkle / the ABC song; trivial in C.
- **Mini Mini Bir Kuş** — short, stepwise, classic.
- **Portakalı Soydum** — simple and very well-known.
- **Ali Baba'nın Çiftliği** — repetitive, kid-singable.

Pick one, run the process, ear-check with Onur.
