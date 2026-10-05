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
    Samples/ du.caf de.caf ta.caf da.caf di.caf be.caf ba.caf bi.caf neutral.caf click_hi.caf click_lo.caf tap.caf
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

- One `AVAudioEngine`, a pool of `AVAudioPlayerNode`s (e.g. 8) → main mixer.
- All samples preloaded as `AVAudioPCMBuffer` at the engine's output format.
- **Scheduling:** compute each event's sample time relative to a block start anchor
  (`AVAudioTime(sampleTime:atRate:)` on the player's timeline, or host time via
  `AVAudioTime(hostTime:)`). Schedule a whole block (count-in + all prompts + clicks) ahead of time;
  never schedule from UI timers.
- Keep a `BlockClock` that maps block-relative seconds ↔ host time
  (`AVAudioTime.hostTime(forSeconds:)` / `seconds(forHostTime:)`), anchored at the scheduled
  start host time.
- Voice syllables: one-shot samples whose perceptual onset is trimmed to sample 0 (see §6).
  Elongations: play the syllable sample; do not stretch.
- Tap sound: short click played on keyDown (low-latency monitoring, toggleable).

## 4. Input and timing

- Capture keys with a local `NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp])`
  while an exercise is active; consume Space/F/J so they don't trigger UI.
- Ignore `event.isARepeat`.
- `NSEvent.timestamp` is seconds since system boot (same timebase as `ProcessInfo.systemUptime`).
  Convert to host time / block time via the `BlockClock`.
  **[verify on device]** that NSEvent timestamps and AVAudio host time share a timebase on the
  target macOS version; the calibration test (below) reveals any constant offset anyway.
- Trackpad/mouse click on the exercise area = Space.

**Latency compensation:**
`tapBlockTime = eventTime − outputLatency − inputOffset`, where
- `outputLatency = engine.outputNode.presentationLatency + ioBufferDuration` (audio reaches the ear
  later than scheduled);
- `inputOffset` = learner's calibrated median offset.

**Calibration screen** (first launch, and in Settings): 16 clicks at 90 BPM, learner taps along;
discard first 4; `inputOffset = median(tap − click)`. Reject calibration if IQR > 40 ms; ask to
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
   calibration, sample voice (bundled / my recordings).
5. **Onboarding** — 4 short screens: what audiation is, syllables, how echo works, calibration.

Notation view: `RhythmStaffView(pattern:, showSyllables:, playhead:)` drawing `NotationLayout`
with `Canvas`. Dark/light mode aware.

Architecture: SwiftUI + `@Observable` view models; one `SessionRunner` (@MainActor) drives an exercise
state machine: `idle → countIn → prompt → response → grading → feedback → next`. Audio callbacks
never touch UI state directly; they post to the main actor.

## 6. Samples

`tools/make_samples.sh` (to be written in M1): generate syllables with macOS `say`
(e.g. `say -v Samantha -o du.aiff "doo"`), convert with `afconvert` to CAF/Linear PCM,
trim leading silence (threshold −40 dBFS) and fade-out to ≤ 250 ms.
Spellings for TTS: Du→"doo", de→"day", ta→"tah", da→"dah", di→"dee", be→"bay", ba→"bah", bi→"bee",
neutral→"bum" **[uncertain: tune by ear; "bah" collides with syllable "ba" — that's why neutral uses "bum"]**.

Later (M5): in-app recording of the user's own voice per syllable, auto-trimmed, replacing the TTS set.

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
