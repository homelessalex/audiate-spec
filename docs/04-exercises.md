# 04 — Exercises

Every exercise is a value type in `AudiateCore` (`ExerciseSpec`) + a SwiftUI view + a grader.
Tap exercises share the onset grader (§2).

## 1. Exercise catalog

| ID | Name | Levels | Prompt | Response | Graded by |
|---|---|---|---|---|---|
| E1 | Echo | AO, VA, GA | Pattern played on hi-hat. AO: by ear only. VA: its notation in view (beat grid, cursor) | Tap it back after the hold measure | Onset grader |
| E2 | Which notation? | VA, GV | Pattern played twice on hi-hat, the 4 notations in view | Pick the notation (keys 1–4); the pulse stops, no time limit | Exact choice |
| E3 | Which meter? | PS, GA | Series of 4 patterns, one meter; fresh count-in with macrobeats only, duple and triple at one macrobeat tempo (66) so neither gives the meter away; no click during the series | Choose meter (pulse stopped, no time limit) | Exact choice |
| E4 | Same or different | GA | Two patterns, same meter | Same / Different | Exact choice |
| E5 | Read | SA (one familiar), CS (series of 4), GS (unfamiliar) | Notation. SA teaching: notation shown while the pattern plays, then read back. SA evaluation: notation only, a silent look-ahead measure before each pattern | Tap (and chant aloud) after count-in | Onset grader |
| E6 | Write (dictation) | SA, CS, GS | Pattern played twice on hi-hat | One cell per macrobeat from the palette (pulse stopped, no time limit); patterns with a pickup, tie or note across a macrobeat are not dictated yet | Structural match |
| E7 | Meter from notation | CS | Series of 4 notated patterns, time signature and beat grid hidden (silent) | Choose meter | Exact choice |
| E8 | Answer differently | IA | Pattern on hi-hat | Tap a *different* pattern in the same meter | Improvisation grader |
| E9 | Compose and perform | IS | Empty measure(s) | Build with palette, then perform it (E5) | E5 grader on own pattern |
| E10 | Hold the pulse | warm-up, free practice | Count-in + 1 measure with click, then silence (2 → 4 → 8 → 16 measures); the click returns at the end | Tap macrobeats through the silence | Pulse grader (never counted toward mastery) |
| E11 | Audiate the gap | drills (after VA) | Pattern, then one **silent** measure | Tap the pattern in the third measure | Onset grader |
| E12 | Theory | TU | Rhythm heard / notation shown | Pick equivalent notation in another time signature; name values | Exact choice |

### Flow of an echo block (E1, E8, E11)

The pulse never stops inside a block:

```
| count-in | prompt | hold | response | lead-in | prompt | hold | response | lead-in | ...
```

- The whole session is one uninterrupted pulse (`FlowSequencer`). The lead-in after a response is the
  next attempt's count-in; the yes/no verdict of the attempt just finished is shown during it.
- A change of meter or tempo (e.g. teaching → evaluation) adds one count-in measure in the new tempo.
- One pattern per attempt. Teaching: the same pattern again until correct (max
  `MasteryPolicy.maxTeachingAttempts`). Evaluation: one attempt per pattern.
- E2 in the flow: `| lead-in | prompt | prompt |`, then the pulse stops until the notation is picked
  (keys 1–4, no time limit); the flow resumes with a count-in.
- When the plan runs out the next session is planned and appended; the flow stops only when there is
  nothing left to practice, or on Esc (pause; resume restarts the interrupted attempt with a count-in).

- Hold: `EchoPolicy.gapMeasures` silent measures (default 1) between prompt and response; the click goes
  on per the click stage. The learner audiates the pattern, then echoes it.

- Count-in: one measure in the pattern's meter: strong click on macrobeats, weak click on microbeats
  (so duple/triple and the unusual grouping are heard before the first pattern). No voice.
- Prompt: open hi-hat on every onset, sustained through elongations and ties, choked at the end of
  the note; rests are silent.
- From `VA`: the pattern's notation is in view during the attempt, with a static beat grid under the
  notes. No cursor or lit notes: following a cursor replaces reading.
- Upbeat patterns: the pickup sits at the end of the preceding measure; response measure is
  likewise preceded by the pickup position. Count-in is shortened accordingly.
- Step size: teaching 1 pattern; evaluation 4–6 patterns of one meter, back to back in the flow.

### Feedback (sound before sight)

- Right after each attempt: **yes / no**, and on "no" the kind of mistake (`AttemptError`):
  missed a beat · extra tap (e.g. on a rest) · timing off (all notes hit, but too far off on average or
  the tempo drifted). No notation, grid, timing strip or counts before the unit reaches `SA`.
- From `SA` on (reading): the verdict also shows the pattern on the staff with a beat grid and a
  comparison: row "notes" (onset + sounding length) and row "you" (taps joined to their notes, error
  in ms, missed/extra in red). While reading: static beat grid only (no cursor, no lit notes).
- No syllables in the UI (VA = notation association).

## 2. Onset grader (E1, E5, E9, E11)

Inputs: expected onsets `E` (seconds from response start; only `note` events), taps `T`
(seconds, latency-compensated, see `05-architecture.md` §4), mode `absolute` (click present) or
`relative` (click absent).

1. **Window:** taps in `[responseStart − pre, responseEnd − pre)`,
   `pre = min(0.12 s, 0.5 × minIOI)` (minIOI = smallest expected inter-onset interval).
2. **Tolerance:** `tol = clamp(0.25 × minIOI, 0.035 s, 0.080 s)`.
3. **Relative mode only:** align first tap to first expected onset, then fit `t = a·e + b` by least
   squares on a preliminary matching with `2 × tol`; constrain `a ∈ [0.85, 1.15]`; map taps through the
   inverse before step 4. Report `a` as tempo drift.
4. **Matching:** monotonic assignment minimizing Σ|t − e| (DP, O(|E|·|T|)), a pair only if
   `|t − e| ≤ tol`. Unmatched expected = **miss**, unmatched tap = **extra**.
5. **Result:** `hits[(expected, tap, signedError)]`, `misses`, `extras`, `meanAbsError`, `maxAbsError`,
   `tempoRatio` (relative mode).
6. **Pass:** `misses == 0 && extras == 0 && maxAbsError ≤ tol && meanAbsError ≤ 0.5 × tol`
   and, in relative mode, `|1 − a| ≤ 0.08`.
7. **Accuracy (for rolling stats):** `hits / (|E| + extras)`.

Key repeat events are ignored. Taps closer than 30 ms to the previous tap are debounced.

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

## 6. Pulse grader (E10)

Expected = macrobeat times continuing the count-in tempo. Silent stretch length grows with
successive passes: 2 → 4 → 8 → 16 measures.
- `drift` = (last tap − last expected) / macrobeat duration.
- `jitter` = SD of inter-tap intervals / macrobeat duration.
- Pass: `|drift| ≤ 0.10` and `jitter ≤ 0.06`. Show drift as "you ended X % early/late".
