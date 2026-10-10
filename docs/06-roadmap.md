# 06 — Roadmap

Implement milestones in order. Each ends with a runnable app and green tests. Do not start the next
milestone until the acceptance criteria are met. Each milestone has a ready-to-paste prompt.

## M0 — Core model (no UI)

Scope: `AudiateCore` package: model, `PatternLibrary`, `SyllableDeriver`, notation value mapping,
difficulty, `NotationLayout` (geometry only), `PatternGenerator`.

Acceptance:
- `swift test` green; all 66 patterns reproduce JSON syllables and notation exactly.
- Generator test (10 000 seeded runs) green.

> Prompt: *Read CLAUDE.md and docs/01–03. Create the Xcode project skeleton and the AudiateCore
> Swift package per docs/05 §1–2. Implement milestone M0 from docs/06. Write the tests first from
> data/patterns.json. Stop when M0 acceptance criteria pass and summarize what you built.*

## M1 — Audio and timing

Scope: `AudiateAudio`: engine, sample bank, block scheduler, `BlockClock`, key capture,
latency compensation, calibration screen; `tools/make_samples.sh`; a debug screen that plays any
pattern from the library with count-in and records taps, printing the `OnsetGrader` result.

Acceptance:
- Debug screen plays `D-DV-03` at 80 BPM with click; tapping along passes the grader on a wired
  output after calibration.
- Loopback/manual check: click jitter < 1 ms (document how it was measured).

> Prompt: *Implement M1 from docs/06 following docs/05 §3–4, §6. Implement OnsetGrader from
> docs/04 §2 in AudiateCore with the listed tests. Add a Debug window (Cmd-Shift-D) to play any
> pattern and grade taps.*

## Status (2026-10-06)

| Milestone | State |
|---|---|
| M0 | done |
| M1 | done (D-DV-03 passed on device; offline-render jitter test) |
| M2 | done, reshaped by the learner's feedback (see below) |
| M3 | done except visual review of reading/dictation on device for U1–U4 |
| M4 | done (device review pending) |
| M5 | two-hand mode, settings, introduction done; the rest open |

Deliberate changes since the original plan (each recorded in `01-methodology.md` §7 and the docs it touches):
no voice (choked hi-hat), VA = notation association instead of syllables, a "hold it" measure before the
response, the session as one uninterrupted pulse with a yes/no verdict per attempt and the error type,
duple and triple units in parallel (groups), daily limits with free practice after the day's work, no
cursor on the staff.

## To check on device as the levels open

Built and covered by tests, not yet tried by the learner. Check each when the level becomes available
and note anything odd:

- [ ] **E10 Hold the pulse** (Home → Pulse trainer, an extra exercise, not in sessions): click / silence
      cycles; the returning click shows how far you drifted.
- [ ] **Stage C** (VA evaluation on): click while listening / looking / holding, silent only while you
      play; grading tolerates a steady tempo change up to 8 %.
- [ ] **E2 Which notation?** (VA): heard twice, four notations, no time limit; the answer stays on screen.
- [ ] **E6 Dictation** (SA): cells per beat with keys 1–9, arrows, ⌫, Return; result shows the first wrong beat.
- [ ] **E5 Reading** (SA): look-ahead measure then read; notes-vs-taps comparison after the attempt.
- [ ] **E3 Which meter?** (PS, after U1 and U2 VA): count-in gives only the macrobeat; duple and triple at 66.
- [ ] **E7 Meter from notation** + series reading (CS): no time signature, no beat grid.
- [ ] **Free practice** after the day's work, and the flow ending with "That's all for today".
- [ ] **Audiate the gap** (end of the first session each day): two silent measures, no click, then echo.
- [ ] **Two hands** (Settings ⌘,): F on every beat, J/Space/pad the rhythm; the verdict names the hand.
- [ ] **Settings and introduction**: session length, tap sound, reset progress; Help → Show Introduction.
- [ ] **GA** (after a unit's VA and SA): echo of unfamiliar patterns at varied tempos; **Same or different?**
- [ ] **GV**: which notation, unfamiliar patterns. **GS**: read and write unfamiliar patterns.
- [ ] **IA Answer differently**: answer with a *different* rhythm; snapped to the grid; an echo is rejected.
- [ ] **IS Compose**: write your own pattern with cells, then perform it from the notation.
- [ ] **Keys** (Settings → Keys): own rhythm/pulse keys; reserved keys refused.
- [ ] **Pulse trainer** (Home): click/silence cycles, drift needle and tempo after each silence, adaptive
      silences, random-dropout mode, beat/half/fine grid, chart at the end.
- [ ] **Accuracy bar** after every tap attempt: mean |error| with the pass tick, full on a miss or extra tap.

## M2 — First playable loop: U1–U2 at AO and VA ✅

Scope (as built): `curriculum.json` with unit groups, `Gate`, `MasteryPolicy`, `LeitnerScheduler`,
SwiftData persistence, `FlowSequencer` + `SessionRunner` (one pulse per session, sessions chained,
daily limits, free practice), E1 echo (by ear at AO, with notation at VA), E2 "which notation?",
yes/no verdict with error type, Home with progress grid.

Acceptance:
- A new user can complete U1 AO → VA across multiple days (simulation test).
- No notation is visible for a unit before it passed AO (simulation test over all steps).

## M3 — Notation: PS, SA, CS ✅ (device review pending)

Scope (as built): `RhythmStaffView` (Bravura via CoreText), contact sheet (`-AudiateContactSheet`),
E5 read (SA, CS series), E6 dictation with a cell palette, E3 which meter (PS), E7 meter from notation
(CS), notes-vs-taps comparison for reading, click stage C for evaluation from VA on.

Acceptance:
- All 66 patterns render correctly (contact sheet reviewed).
- Reading and dictation work for U1–U4 — *to confirm on device*.
- Simulation: U1 passes SA, PS and CS within two weeks.

Known gaps: dictation of patterns with pickups, ties or notes across a macrobeat (palette has no tie /
pickup slot yet); unit-level review items (PS, CS) are not scheduled for review.

## M4 — Inference: GA, GV, GS, IA, IS + drills

Done: E10 hold the pulse (`PulseGrader`, 2 → 4 → 8 → 16 silent measures, daily warm-up — later moved out of sessions into the pulse trainer); audiation drill
closing the first session of the day (E11: familiar patterns, two silent measures without click, practice).

Done as well: generated (unfamiliar) patterns for GA/GV/GS from the content of every unit past VA, tempo
drawn from the meter's range per step, E4 same/different, E8 answer differently (`ImprovGrader`), E9
compose then perform; inference levels mastered per unit (15 attempts on 2 days, 80 %).

Open: bridging after two misses is scheduled in the core but only for familiar-pattern items; check it
once symbolic levels are in use. Generalization in U1 alone has no unfamiliar patterns (macro/micro
cells give only the four library patterns) — it starts once U3's divisions are known.

Acceptance:
- Session planner tests green; a session contains review, new, drill.
- Improvisation grader accepts a valid different answer and rejects an exact echo.

## M5 — Polish

Done: two-hand mode (`TwoHandGrade`, F = macrobeats), settings (session length, two hands, tap sound,
calibration, reset), introduction on first launch (Help → Show Introduction).

Open: grade-sustain option (off: drum parts first; revisit for keyboards), U5–U12 content verified
end-to-end, theory track (E12), app icon, sandboxing, notarized build.

## M6 — Phrase reading (E13)

Scope: `PhraseSpec`, `PhrasePolicy` (ladder), `Timeline.phraseBlock`, per-measure `PhraseGrade`, the flow kind
`readPhrase` (review held for measures, the pulse goes on), planner step once a unit has passed CS, phrase staff and review screen.

Acceptance:
- The ladder climbs after 3 passes in a row and steps back after 2 misses (tests).
- A phrase passes only when every measure passes; a tap early for the next measure counts for that measure.
- No phrase before a unit passed CS; no pickup patterns in phrases (planner tests).

## Later (optional)

- Microphone onset detection for clapping.
- Intact unusual meters, multimetric patterns.
- iPad/iPhone target (core package is already platform-neutral).
