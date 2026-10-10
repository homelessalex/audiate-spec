# 04 — Exercises

Every exercise is a value type in `AudiateCore` (`ExerciseSpec`) + a SwiftUI view + a grader.
Tap exercises share the onset grader (§2).

## 1. Exercise catalog

| ID | Name | Levels | Prompt | Response | Graded by |
|---|---|---|---|---|---|
| E1 | Echo | AO, VA, GA | Pattern played on hi-hat. AO: by ear only. VA: its notation in view (beat grid, cursor) | Tap it back after the hold measure | Onset grader |
| E2 | Which notation? | VA, GV | Pattern played twice on hi-hat, the 4 notations in view | Pick the notation (keys 1–4); the pulse stops, no time limit | Exact choice |
| E3 | Which meter? | PS, GA | Series of 4 patterns, one meter; fresh count-in with macrobeats only, duple and triple at one macrobeat tempo (66) so neither gives the meter away; no click during the series | Choose meter (pulse stopped, no time limit) | Exact choice |
| E4 | Same or different | GA | Two unfamiliar patterns, same meter (different = one onset changed), no click | Same / Different (pulse stopped) | Exact choice |
| E5 | Read | SA (one familiar), CS (series of 4), GS (unfamiliar) | Notation. SA teaching: notation shown while the pattern plays, then read back. SA evaluation: notation only, shown `EchoPolicy.readLookMeasures` (2) measures before it is read — look at it, hear it inside, read | Tap (and chant aloud) after count-in | Onset grader |
| E6 | Write (dictation) | SA, CS, GS | Pattern played twice on hi-hat | One cell per macrobeat from the palette (pulse stopped, no time limit); patterns with a pickup, tie or note across a macrobeat are not dictated yet | Structural match |
| E7 | Meter from notation | CS | Series of 4 notated patterns, time signature and beat grid hidden (silent) | Choose meter | Exact choice |
| E8 | Answer differently | IA | Unfamiliar pattern on hi-hat, hold measure, no click | Tap a *different* pattern in the same meter | Improvisation grader |
| E9 | Compose and perform | IS | Empty measure | Build with the cell palette (pulse stopped), then read it in the flow (stage C) | Onset grader on own pattern |
| E10 | Hold the pulse | pulse trainer on Home (extra, not in sessions) | Count-in + 2 measures with click, then silence (2 → 4 → 8 → 16 measures); the click returns at the end | Tap macrobeats through the silence | Pulse grader (never counted toward mastery) |
| E11 | Audiate the gap | drills (after VA) | Pattern, then one **silent** measure | Tap the pattern in the third measure | Onset grader |
| E12 | Theory | TU | Rhythm heard / notation shown | Pick equivalent notation in another time signature; name values | Exact choice |
| E13 | Read a phrase | phrase track (after a unit passes CS) | A phrase of 2–4 familiar patterns, one per measure, one meter, in view as a whole for `EchoPolicy.readLookMeasures` measures | Read it measure after measure without a break; the review follows in the next measures, the pulse goes on | Onset grader per measure; pass = every measure |

### Flow of an echo block (E1, E8, E11)

The pulse never stops inside a block:

```
| count-in | prompt | hold | response | lead-in | prompt | hold | response | lead-in | ...
```

- The whole session is one uninterrupted pulse (`FlowSequencer`). The lead-in after a response is the
  next attempt's count-in; the yes/no verdict of the attempt just finished is shown during it.
- A change of tempo (e.g. teaching → evaluation) adds one count-in measure in the new tempo; a change of
  meter, and the start of a session, get two (`EchoPolicy.newMeterCountInMeasures`) to settle in.
- One pattern per attempt. Teaching: the same pattern again until correct (max
  `MasteryPolicy.maxTeachingAttempts`). Evaluation: the first try is graded; after a miss the same
  pattern comes again right away as a correction ("Fix it", practice, not graded) until it is right,
  at most `MasteryPolicy.maxCorrectionAttempts` tries in all. Applies to tap exercises (echo, reading,
  answer differently); choice questions and the pulse drill don't repeat.
- E2 in the flow: `| lead-in | prompt | prompt |`, then the pulse stops until the notation is picked
  (keys 1–4, no time limit); the flow resumes with a count-in.
- When the plan runs out the next session is planned and appended; the flow stops only when there is
  nothing left to practice, or on Esc (pause; resume restarts the interrupted attempt with a count-in).

- Hold: `EchoPolicy.gapMeasures` silent measures (default 1) between prompt and response; the click goes
  on per the click stage. The learner audiates the pattern, then echoes it.

- Count-in: one measure in the pattern's meter: low click on the downbeat, strong click on the other macrobeats, weak click on microbeats
  (so duple/triple and the unusual grouping are heard before the first pattern). No voice.
- Prompt: open hi-hat on every onset, sustained through elongations and ties, choked at the end of
  the note; rests are silent.
- From `VA`: the pattern's notation is in view during the attempt, with a static beat grid under the
  notes. No cursor or lit notes: following a cursor replaces reading.
- Upbeat patterns: the pickup sits at the end of the preceding measure; response measure is
  likewise preceded by the pickup position. Count-in is shortened accordingly.
- Step size: teaching 1 pattern; evaluation 4–6 patterns of one meter, back to back in the flow.

### Feedback (sound before sight)

- Right after each attempt an **accuracy bar** (`AccuracyScore`): the mean |tap − note| over the notes, on a
  scale ending at the tolerance, with a tick where the mean must stay to pass (½ tolerance); a missed note
  or an extra tap fills it. One number, not a picture of the rhythm, so it is shown at every level.
- Right after each attempt: **yes / no**, and on "no" the kind of mistake (`AttemptError`):
  missed a beat · extra tap (e.g. on a rest) · timing off (all notes hit, but too far off on average or
  the tempo drifted). No notation, grid, timing strip or counts before the unit reaches `SA`.
- From `SA` on (reading): the verdict also shows the pattern on the staff with a beat grid and a
  comparison: row "notes" (onset + sounding length) and row "you" (taps joined to their notes, error
  in ms, missed/extra in red). While reading: static beat grid only (no cursor, no lit notes).
- No syllables in the UI (VA = notation association).

### Reading a phrase (E13)

Sight reading of familiar forms: several patterns joined into one line, read without stopping.

```
| count-in | look | hear it inside | measure 1 | measure 2 | (measure 3 | measure 4) | review … | lead-in (review) | look | …
```

- **Content:** patterns of every unit that passed `CS`, in one meter, mixed across units, in random
  order; the same pattern never twice in a row (when the meter has two or more). Patterns with a pickup
  are left out (the pickup would overlap the measure before it).
- **Ladder** (`PhrasePolicy.rungs`, **[uncertain]**): the phrase grows and the tempo rises step by step,
  `2 measures × 85 / 92 / 100 %` of the standard tempo → `3 × 92 / 100 %` → `4 × 92 / 100 %`, never below
  the meter's tempo range (triple 48 → 52 → 56, duple 68 → 74 → 80).
  `PhrasePolicy.passesToAdvance` (3) graded phrases in a row passed → next rung;
  `PhrasePolicy.failsToStepBack` (2) failed in a row → one rung back. The rung is derived from the
  graded attempts (each records its rung), never stored on its own.
- **Click:** macrobeats throughout (stage B, absolute timing): the task is reading, not holding the pulse.
  One even click in every measure — look, phrase, review, lead-in; the microbeats of a count-in only where
  the stream starts or the tempo changes, so the click never thickens and thins out between phrases.
- **During the phrase:** the whole line stays in view with the beat grid; no cursor, no per-measure marks —
  the eyes have to stay ahead, on the next measure.
- **After the phrase:** the pulse goes on, as everywhere. For `PhrasePolicy.passedReviewMeasures` (1)
  measure after a pass, `missedReviewMeasures` (3) after a miss, every measure of the phrase shows notes
  vs. taps (the reading comparison), failed ones framed in red; the macrobeat click goes on, and the last
  of these measures is the next attempt's lead-in (still "How it went", no "Get ready" of its own). After a miss the same phrase
  comes again as a correction (max `MasteryPolicy.maxCorrectionAttempts`
  tries, only the first graded).
- **Pass:** every measure passes the onset grader (each measure is graded on its own slot; full strictness).
- **Amount:** `PhrasePolicy.phrasesPerStep` (4) phrases per step, at most `PhrasePolicy.maxPhrasesPerDay`
  (12) graded phrases a day. Not counted toward level mastery or Leitner review: the ladder is its progress.
  "Read phrases" on Home is endless: after the day's graded phrases it goes on as practice at the current
  rung (not counted, the ladder stays) until the learner ends it.

## 2. Onset grader (E1, E5, E9, E11, E13)

Inputs: expected onsets `E` (seconds from response start; only `note` events), taps `T`
(seconds, latency-compensated, see `05-architecture.md` §4), mode `absolute` (click present) or
`relative` (click absent).

1. **Window:** taps in `[responseStart − pre, responseEnd − pre)`,
   `pre = min(0.12 s, 0.5 × minIOI)` (minIOI = smallest expected inter-onset interval).
2. **Tolerance:** `tol = clamp(0.25 × minIOI, 0.035 s, 0.080 s)`.
3. **Relative mode only:** align first tap to first expected onset to make a preliminary matching with
   `2 × tol`; on it fit the learner's tempo and phase, `t = a·e + b`, constrained to `a ∈ [0.85, 1.15]`.
   - *For the errors* the fit is regularized toward `a = 1, b = 0` (ridge; tap spread 25 ms, tempo
     spread 5 %, offset spread 20 ms — `OnsetGraderPolicy`, **[uncertain]**), taps are mapped through its
     inverse before step 4, and each hit's error is its **leave-one-out** residual `r / (1 − h)` — the note
     measured against the pulse the *other* notes imply. A plain fit has two free parameters: it matches
     two taps exactly and most of three, so the error read ~0 ms whatever the taps were.
   - *For the drift rule* (step 6) and the report, `a` is the plain least-squares slope.
   - A constant offset stays forgiven, in stage C too: it may be latency the calibration missed rather
     than the learner's timing.
4. **Matching:** monotonic assignment minimizing Σ|t − e| (DP, O(|E|·|T|)), a pair only if
   `|t − e| ≤ tol`. Unmatched expected = **miss**, unmatched tap = **extra**.
5. **Result:** `hits[(expected, tap, signedError)]`, `misses`, `extras`, `meanAbsError`, `maxAbsError`,
   `tempoRatio` (relative mode).
6. **Pass:** `misses == 0 && extras == 0 && maxAbsError ≤ tol && meanAbsError ≤ 0.5 × tol`
   and, in relative mode, `|1 − a| ≤ 0.08`. A drift is told as such ("Tempo drifted: you slowed down
   9 %"), not as "Timing off": the note errors are measured against the learner's own tempo, so they can
   all be small while the tempo itself changed.
7. **Accuracy (for rolling stats):** `hits / (|E| + extras)`.

Key repeat events are ignored. A tap closer than 50 ms after the previous one of the same hand is a double trigger (key bounce, a MIDI
pad firing twice): `TapRecorder` drops it — no tap sound, not counted — and the grader debounces again.
The fastest real notes are ~130 ms apart, so this never eats one.

**Optional (setting "Grade sustain", off by default — not implemented yet):** the learner's goal is
drum parts, where a note's length is set by the next stroke, not by holding; revisit for keyboards.
 for notes ≥ 24 ticks, key must stay down
≥ 60 % of the note's duration; for rests, key must be up. Rationale: MLT stresses sustaining
elongations; this is the keyboard analogue.

### Two-hand mode (setting, any tap exercise)

Left key (`F`) = macrobeats, right key (`J`) = melodic rhythm. Grade melodic rhythm as above; grade
macrobeats separately with the same grader (expected = macrobeat starts). Pass requires both.
Space bar = melodic rhythm in one-hand mode.

## 3. Structural match (E6 writing)

Compare learner's event list with the target:
- **SA / CS / GS:** accept if the *sound* is identical: same onset set and same rest spans.
  A tie and an equivalent single notated value count as equal (e.g. `12 24 12` == `12 12~12 12`).
- **TU:** require exact notation.
- Feedback: highlight the first differing macrobeat.

Palette UI: one slot per macrobeat; palette shows the unlocked cells (`cells.json`) as small
notation tiles; number keys 1–9 pick tiles; arrows move between slots; `T` toggles tie into next
slot; `P` toggles a pickup slot (if upbeat unlocked). Play button auditions the written result.

## 4. Choice exercises (E2, E3, E4, E7, E12)

- 4 options (E3: number of unlocked meters, min 2).
- E2 distractors: same meter, generated by moving/adding/removing one onset (or swapping one macrobeat
  cell when that gives too few), all valid and notatable, all sounding different from the target and
  from each other.
- E2 is heard twice (no replay button); the choice has no time limit.
- Pass = correct choice.

## 5. Improvisation grader (E8)

1. Quantize each tap to the nearest grid point of the unlocked content (division grid = 6 ticks;
   thirds if combined unlocked) using the tempo; require all quantization errors ≤ `tol`.
2. Response must fit inside the measure and contain ≥ 2 onsets.
3. Quantized pattern must **differ** from the prompt (different onset set).
4. Pulse held: relative-mode `a` within ±8 %.
Pass = all four. Show the quantized result (from `SA` on as notation; before that as syllables only).

## 6. Pulse trainer and pulse grader (E10)

**Pulse trainer** (Home → Pulse trainer, `PulseTrainer`): an endless stream
`| click 2 | silence N | click 2 | silence N | …` — or, in random-dropout mode, the click vanishing for
1…n measures at unpredictable places. The returning click is the feedback by ear; while it plays the
screen shows where the last silence ended (needle early ↔ late, % of a beat and ms), the tempo the taps
implied (sped up / slowed down / steady) and evenness. Steady (|drift| < 5 % of a beat, even, right
count) → longer silences (2, 4, 6, 8, 12, 16 measures); |drift| > 15 % or a lost count → shorter.
The learner taps beats, beats + halves/thirds, or the fine grid. After stopping: a chart of the drift
per silence and the tendency (rushing / slowing). Practice only, never recorded toward progress;
it is not part of sessions.

Expected = macrobeat times continuing the count-in tempo. Silent stretch length grows with
successive passes: 2 → 4 → 8 → 16 measures.
- `drift` = (last tap − last expected) / macrobeat duration.
- `jitter` = SD of inter-tap intervals / macrobeat duration.
- Pass: `|drift| ≤ 0.10` and `jitter ≤ 0.06`. Show drift as "you ended X % early/late".
