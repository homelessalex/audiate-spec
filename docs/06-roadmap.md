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
| M4 | E10 done (warm-up, free practice); the rest open |
| M5 | open |

Deliberate changes since the original plan (each recorded in `01-methodology.md` §7 and the docs it touches):
no voice (choked hi-hat), VA = notation association instead of syllables, a "hold it" measure before the
response, the session as one uninterrupted pulse with a yes/no verdict per attempt and the error type,
duple and triple units in parallel (groups), daily limits with free practice after the day's work, no
cursor on the staff.

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

Done: E10 hold the pulse (`PulseGrader`, 2 → 4 → 8 → 16 silent measures, daily warm-up).

Open: E4 same/different, E8 answer differently (improvisation grader), E9 compose and perform, generator
integration for GA/GV/GS (unfamiliar patterns), tempo randomization within range, bridging in the
planner (core scheduling exists), audiation drill at the end of a session.

Acceptance:
- Session planner tests green; a session contains warm-up, review, new, drill.
- Improvisation grader accepts a valid different answer and rejects an exact echo.

## M5 — Polish

Two-hand mode, grade-sustain option (off: drum parts first; revisit for keyboards), onboarding (what
audiation is, how the flow works, calibration), settings (session length), U5–U12 content verified
end-to-end, theory track (E12), app icon, sandboxing, notarized build.

## Later (optional)

- MIDI input (`CoreMIDI`, note-on timestamps → host time) as an alternative tap source.
- Microphone onset detection for clapping.
- Intact unusual meters, multimetric patterns.
- iPad/iPhone target (core package is already platform-neutral).
