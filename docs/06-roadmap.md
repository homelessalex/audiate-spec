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

## M2 — First playable loop: U1–U2 at AO and VA

Scope: `curriculum.json`, `Gate`, `MasteryPolicy`, `LeitnerScheduler`, SwiftData persistence,
`SessionRunner` state machine, Session screen with E1 (echo) and E2 (name the syllables),
feedback without visuals (sound-before-sight), click stages A/B, Home with progress grid,
synchronized syllable text for VA teaching mode (`Timeline.prompts[].cues`).

Acceptance:
- A new user can complete U1 AO → VA across multiple days (simulate dates in tests).
- No pattern's notation is shown before its AO teaching echoes (planner test). *(Changed: sound before
  sight per pattern; reading with notation was pulled forward from M3.)*

> Prompt: *Implement M2 from docs/06. Curriculum and gates per docs/02 §1–4; exercises E1 and E2 per
> docs/04. Mastery thresholds in one MasteryPolicy file. Add date injection for tests.*

## M3 — Notation: PS, SA, CS

Scope: `RhythmStaffView` (Bravura, Canvas), E3, E5, E6 with palette, E7, timeline overlay feedback,
click stage C.

Acceptance:
- All 66 patterns render correctly (snapshot image per pattern, reviewed manually once).
- Reading and dictation work for U1–U4.

> Prompt: *Implement M3 from docs/06: NotationLayout → RhythmStaffView per docs/03 §3–4, exercises E3,
> E5, E6, E7 per docs/04. Generate a PNG contact sheet of all patterns for visual review.*

## M4 — Inference: GA, GV, GS, IA, IS + drills

Scope: E4, E8, E9, E10, E11, generator integration, tempo randomization, bridging, full
`SessionPlanner` with warm-up and audiation drill.

Acceptance:
- Session planner tests green; a 12-minute session contains warm-up, review, new, drill.
- Improvisation grader accepts a valid different answer and rejects an exact echo.

## M5 — Polish

Two-hand mode, grade-sustain option, onboarding (incl. how to pronounce the syllables), settings, U5–U12 content
verified end-to-end, theory track (E12), app icon, sandboxing, notarized build.

## Later (optional)

- MIDI input (`CoreMIDI`, note-on timestamps → host time) as an alternative tap source.
- Microphone onset detection for clapping.
- Intact unusual meters, multimetric patterns.
- iPad/iPhone target (core package is already platform-neutral).
