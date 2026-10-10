# 05 — Architecture

## 1. Project layout

```
Audiate/
  Audiate.xcodeproj               (app target, macOS 14+)
  App/                            SwiftUI app: screens, view models, navigation
  Packages/
    AudiateCore/                  pure Swift: model, syllables, notation layout data, grading,
                                  generator, curriculum, mastery, session planner
    AudiateAudio/                 AVAudioEngine sequencer, sample bank, clock, latency calibration
  Resources/
    patterns.json, cells.json, curriculum.json
    Bravura.otf (+ OFL.txt)
    Samples/ hihat_open.caf beat_strong.caf beat_weak.caf tap.caf
  tools/build_patterns.py, tools/make_samples.sh
```

`AudiateCore` has no Apple UI/audio imports → fast `swift test` without the app.

## 2. Core types (AudiateCore)

| Type | Responsibility |
|---|---|
| `Meter`, `Pattern`, `RhythmEvent`, `ContentKind` | Model (`03-rhythm-model.md`) |
| `PatternLibrary` | Loads `patterns.json`, `cells.json`; lookup by unit/meter/content |
| `SyllableTable`, `SyllableDeriver` | Syllables from position |
| `NotationLayout` | Converts a pattern into drawable items (glyph, x, beams, ties, tuplets) — pure geometry, no drawing |
| `PatternGenerator` | Unfamiliar patterns (seeded RNG for tests) |
| `Timeline` | Pattern + tempo + click stage → list of timed audio events and expected onsets |
| `OnsetGrader`, `ImprovGrader`, `PulseGrader`, `StructuralMatcher` | `04-exercises.md` |
| `Curriculum`, `Gate` | Units, levels, unlock logic |
| `MasteryPolicy`, `LeitnerScheduler` | Thresholds, review intervals, bridging |
| `SessionPlanner` | Builds today's session (list of `ExerciseSpec`) |
| `ExerciseSpec` | Enum of E1–E12 with parameters |

## 3. Audio (AudiateAudio)

- One `AVAudioEngine`. A block is pre-mixed by `BlockMixer` into one buffer, with every sound at an exact
  sample offset, and played on one `AVAudioPlayerNode`; a second node plays the tap sound
  (see `timing-verification.md`).
- All samples preloaded as mono Float32 (`SampleBank`).
- **Scheduling:** compute each event's sample time relative to a block start anchor
  (`AVAudioTime(sampleTime:atRate:)` on the player's timeline, or host time via
  `AVAudioTime(hostTime:)`). Schedule a whole block (count-in + all prompts + clicks) ahead of time;
  never schedule from UI timers.
- **The metronome is the source of truth.** Sessions and the pulse trainer are open-ended streams played
  by `StreamFeeder` on its own queue: it renders 1024-frame chunks from the current `StreamPlan` and
  schedules each at its own sample time on the player's timeline, ~0.17 s ahead of what is heard. The main
  thread takes no part, so a busy or hung UI can't delay, drop or shift the pulse.
  - `StreamPlan` (AudiateCore) is a snapshot: the sounds decided so far, `decidedUntil`, an optional end,
    and a `ClickContinuation` — the last measure's clicks repeated on the measure grid. Past
    `decidedUntil` the audio plays the continuation, so the pulse goes on while an outcome is pending.
  - When the UI decides something (an attempt graded, the next silence of the pulse trainer) it lays it
    out no earlier than `StreamFeeder.notBefore` (rendered position + 50 ms) and hands over the new plan.
    If the decision came late, `FlowSequencer` / `PulseTrainer` insert more lead-in (clicked) measures:
    the next attempt starts a measure later, on the grid; nothing shifts.
  - If the feeder itself ever falls behind real time, the late stretch is skipped, not played late, so the
    audio stays on the clock that the UI and the grading read. Underruns and notes decided too late are
    counted (`StreamFeeder.stats`) and logged (subsystem `app.audiate`, category `stream`).
  - The UI follows the clock: every frame it asks which measure is being heard (`BlockClock`, minus the
    output latency) and draws that; after a hang it simply shows where the pulse is now.
- Keep a `BlockClock` that maps block-relative seconds ↔ host time
  (`AVAudioTime.hostTime(forSeconds:)` / `seconds(forHostTime:)`), anchored at the scheduled
  start host time.
- No voice. Prompt notes use a long open hi-hat sample, cut at the note's sounding duration
  (`ScheduledSound.duration`, ties included) with a 10 ms choke fade. Clicks are one-shots.
- Tap sound: short click played on keyDown (low-latency monitoring, toggleable).

## 4. Input and timing

- Capture keys with a local `NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp])`
  while an exercise is active; consume the tap keys so they don't trigger UI. Tap keys are a `KeyMap`
  set in Settings (default rhythm Space/J, pulse F); 1–9, Return, Esc, arrows and Delete are reserved.
- Ignore `event.isARepeat`.
- `NSEvent.timestamp` is seconds since system boot (same timebase as `ProcessInfo.systemUptime`).
  Convert to host time / block time via the `BlockClock`.
  **[verify on device]** that NSEvent timestamps and AVAudio host time share a timebase on the
  target macOS version; the calibration test (below) reveals any constant offset anyway.
- Trackpad/mouse click on the exercise area = Space.
- **MIDI keyboard / pads** (`MIDIInput`, CoreMIDI): one app-wide client connects every source and
  reconnects on setup changes. Only note-on with velocity > 0 counts (UMP, MIDI 1.0 protocol). The
  packet's host timestamp is the tap time (0 → `mach_absolute_time()`), which is more exact than
  `NSEvent.timestamp`. One hand: every note is the rhythm. Two hands: notes below `MIDISplit`
  (default C4, "Learn…" in Settings) keep the pulse, the rest play the rhythm.

**Latency compensation:**
`tapBlockTime = eventTime − outputLatency − inputOffset`, where
- `outputLatency = engine.outputNode.presentationLatency + ioBufferDuration` (audio reaches the ear
  later than scheduled);
- `inputOffset` = learner's calibrated median offset, per input source (computer keys/pad vs. MIDI);
  an uncalibrated MIDI keyboard borrows the computer offset. `TapRecorder` removes both before grading.

**Calibration screen** (first launch, and in Settings): 16 clicks at 90 BPM, learner taps along;
discard first 4; `inputOffset = median(tap − click)`, stored for the source most taps came from. Reject calibration if IQR > 40 ms; ask to
repeat. Store per audio output device (headphones vs. speakers differ; Bluetooth adds 100–250 ms —
show a warning when the output is Bluetooth).

## 5. UI (App target)

Screens:
1. **Home** — today's session button, streak-free progress grid (units × levels, colored by state:
   locked / available / in progress / passed), due reviews count.
2. **Session** — full-window, minimal. Big pulse indicator (macrobeat flash; hidden in stage C/D),
   exercise area, feedback panel. Keyboard-first: Space taps, Return continues, Esc pauses.
3. **Unit detail** — patterns of a unit with per-level status; free practice of any unlocked item
   (does not count toward gates unless in evaluation mode).
4. **Settings** — session length, tempo offsets, click override, two-hand mode, grade sustain,
   calibration.
5. **Onboarding** — 4 short screens: what audiation is, syllables, how echo works, calibration.

Notation view: `RhythmStaffView(pattern:, showSyllables:, playhead:)` drawing `NotationLayout`
with `Canvas`. Dark/light mode aware.

Architecture: SwiftUI + `@Observable` view models; one `SessionRunner` (@MainActor) drives an exercise
state machine: `idle → countIn → prompt → response → grading → feedback → next`. Audio callbacks
never touch UI state directly; they post to the main actor.

## 6. Samples

`tools/make_samples.sh` synthesizes percussion with `tools/synth_samples.py` (stdlib only) and converts
it with `afconvert` to CAF (mono, 16-bit, 44.1 kHz, attack at sample 0):

| Sample | Use | Sound |
|---|---|---|
| `hihat_open` | prompt notes | 808-style open hi-hat, 3.5 s, choked by the mixer |
| `beat_strong` | click / count-in on macrobeats | crisp tick (1 kHz, ~7 ms decay), louder than `beat_weak` |
| `beat_weak` | click / count-in on microbeats | short crisp tick (1.8 kHz, ~4 ms decay), quieter than `beat_strong` |
| `tap` | key press feedback | short noise tick |

No voice samples (deliberate, see `01-methodology.md` §7). **[uncertain]** Timbres are a first pass; tune by ear.

## 7. Persistence (SwiftData)

| Model | Fields |
|---|---|
| `AttemptRecord` | id, date, exerciseKind, level, unitId, patternId?, generatedPatternJSON?, mode (teaching/evaluation), clickStage, tempo, passed, accuracy, meanAbsErrorMs, tempoRatio? |
| `ItemState` | key (patternId or unitId + level), leitnerBox, dueDate, passDays [Date], consecutiveFails |
| `LevelState` | unitId, level, status (locked/available/inProgress/passed), passedAt? |
| `CalibrationProfile` | outputDeviceUID, inputOffsetMs, date |
| `Settings` | via `@AppStorage` |

Gate and mastery decisions are computed in `AudiateCore` from plain structs; SwiftData models are
mapped to/from those structs at the boundary.

## 8. Testing

- `AudiateCore` unit tests (Swift Testing):
  - every pattern in `patterns.json`: Swift syllables == JSON `syllables`; notation == JSON notation;
    measure sums.
  - `OnsetGrader`: perfect taps pass; each of ±(tol+1 ms), missing tap, extra tap fails; relative
    mode passes with uniform 5 % tempo scaling, fails at 10 %.
  - `PatternGenerator`: 10 000 seeded generations are valid, unfamiliar, respect unlocked content.
  - `Gate`/`MasteryPolicy`/`LeitnerScheduler`: table-driven scenarios incl. bridging.
  - `SessionPlanner`: respects shares, block grouping by meter, max new patterns.
- Audio timing smoke test (manual, documented): loopback recording of scheduled clicks; verify
  inter-onset jitter < 1 ms.
- UI against the audio (manual, dev): launch with `-AudiateSoak /path/frames.csv` — progress in memory (the
  real store untouched), audio muted, "Read phrases" with no taps for 40 s. Every frame is logged (uptime,
  heard time, pulse light, measure role), then the macrobeat clicks played. From it: frame time per measure
  role, and how long after each click the pulse light came on (one frame, ≤ 17 ms, is the goal). Only the
  session header redraws every frame; the content below it changes once per measure, 150 ms after the
  downbeat (`FlowView.contentLag`), so laying out a review never delays the light of a click.
