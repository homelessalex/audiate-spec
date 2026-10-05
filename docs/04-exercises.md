# 04 — Exercises

Every exercise is a value type in `AudiateCore` (`ExerciseSpec`) + a SwiftUI view + a grader.
Tap exercises share the onset grader (§2).

## 1. Exercise catalog

| ID | Name | Levels | Prompt | Response | Graded by |
|---|---|---|---|---|---|
| E1 | Echo | AO, VA, GA | Pattern played on hi-hat (VA teaching mode: syllables shown in sync as text) | Tap it back in the next measure | Onset grader |
| E2 | Name the syllables | VA, GV | Pattern played on hi-hat | Choose syllable string (4 options) | Exact choice |
| E3 | Which meter? | PS, GA | Series of 4 patterns, one meter | Choose meter | Exact choice |
| E4 | Same or different | GA | Two patterns, same meter | Same / Different | Exact choice |
| E5 | Read | SA (one familiar), CS (series of 4), GS (unfamiliar) | Notation. SA teaching: notation shown while the pattern plays, then read back. SA evaluation: notation only, a silent look-ahead measure before each pattern | Tap (and chant aloud) after count-in | Onset grader |
| E6 | Write (dictation) | SA, CS, GS | Pattern played twice on hi-hat | Build notation from cell palette | Structural match |
| E7 | Meter from notation | CS | Series of patterns, time signature hidden | Choose meter / time signature | Exact choice |
| E8 | Answer differently | IA | Pattern on hi-hat | Tap a *different* pattern in the same meter | Improvisation grader |
| E9 | Compose and perform | IS | Empty measure(s) | Build with palette, then perform it (E5) | E5 grader on own pattern |
| E10 | Hold the pulse | warm-up, drills | 2 measures with click, then silence | Tap macrobeats through silence | Pulse grader |
| E11 | Audiate the gap | drills (after VA) | Pattern, then one **silent** measure | Tap the pattern in the third measure | Onset grader |
| E12 | Theory | TU | Rhythm heard / notation shown | Pick equivalent notation in another time signature; name values | Exact choice |

### Flow of an echo block (E1, E8, E11)

The pulse never stops inside a block:

```
| count-in | prompt 1 | hold | response 1 | prompt 2 | hold | response 2 | ... | (end)
```

- Hold: `EchoPolicy.gapMeasures` silent measures (default 1) between prompt and response; the click goes
  on per the click stage. The learner audiates the pattern, then echoes it.

- Count-in: one measure in the pattern's meter: strong click on macrobeats, weak click on microbeats
  (so duple/triple and the unusual grouping are heard before the first pattern). No voice.
- Prompt: open hi-hat on every onset, sustained through elongations and ties, choked at the end of
  the note; rests are silent.
- Syllables (from `VA`, teaching mode): shown as text, each highlighted while its event sounds
  (`Timeline.prompts[].cues`). Hidden in evaluation mode; shown after the attempt.
- Upbeat patterns: the pickup sits at the end of the preceding measure; response measure is
  likewise preceded by the pickup position. Count-in is shortened accordingly.
- Block size: 4–6 patterns, same meter.

### Feedback (respect "sound before sight")

- Before the unit reaches `SA`: **no visual rhythm** (no grid, no notation). Feedback = pass/fail,
  counts of early / late / missed / extra, and an audio replay "model vs. you" (model on left channel
  or alternating).
- From `SA` on: overlay timeline (expected onsets vs. taps, colored by error) under the notation.
- Syllables are shown after the attempt from `VA` on.

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

**Optional (setting "Grade sustain", off by default):** for notes ≥ 24 ticks, key must stay down
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
- E2 distractors: same meter, generated by moving/adding/removing one onset, all must be valid
  patterns with derivable syllables. Never use a distractor equal to the target.
- Replay allowed up to 2 times in teaching mode, 1 time in evaluation mode.
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
