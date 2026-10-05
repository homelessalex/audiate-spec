# 02 — Curriculum

The curriculum is a grid: **content units** (what rhythms) × **skill levels** (what the learner does
with them). Progress moves along both axes; gates decide what is unlocked.

## 1. Content units

Duple and triple are introduced together from the start (MLT does not finish duple before triple).

| Unit | Meter(s) | Content | Patterns (`patterns.json` id prefix) |
|---|---|---|---|
| U1 | usual duple | macro/micro beats | `D-MM-*` |
| U2 | usual triple | macro/micro beats | `T-MM-*` |
| U3 | usual duple | divisions | `D-DV-*` |
| U4 | usual triple | divisions | `T-DV-*` |
| U5 | usual duple | elongations | `D-EL-*` |
| U6 | usual triple | elongations | `T-EL-*` |
| U7 | duple + triple | rests | `D-RS-*`, `T-RS-*` |
| U8 | duple + triple | ties | `D-TI-*`, `T-TI-*` |
| U9 | duple + triple | upbeats | `D-UB-*`, `T-UB-*` |
| U10 | usual combined | triplets in duple | `C-*` |
| U11 | unusual paired | 5/8 (2+3, 3+2) | `UP-*` |
| U12 | unusual unpaired | 7/8 (2+2+3, 3+2+2, 2+3+2) | `UU-*` |

Units are data, not code: define them in `curriculum.json` (to be created in milestone M2) as
`{ id, title, patternIdPrefixes[], meters[] }`, so units can be added without code changes.

## 2. Skill levels per unit

Codes from `01-methodology.md` §4. Each unit runs through:

`AO → VA → PS → SA → CS → GA → GV → GS → IA → IS`

`TU` (theory) is a separate global track unlocked after U4 reaches `CS`.

## 3. Gates (what unlocks what)

| To unlock | Requires |
|---|---|
| U(n+1) `AO` | U(n) `VA` passed |
| U(n) `VA` | U(n) `AO` passed |
| U(n) `PS` | U(n) `VA` passed **and** at least two different meters have `VA` passed (PS needs a contrast). For U1 this means PS waits until U2 `VA`. |
| U(n) `SA` | U(n) `PS` passed — **sound before sight: no notation of a unit's patterns before this** |
| U(n) `CS` | U(n) `SA` passed |
| U(n) `GA`, `GV` | U(n) `VA` passed and U(n) `SA` passed |
| U(n) `GS` | U(n) `CS` and `GV` passed |
| U(n) `IA` | U(n) `GV` passed |
| U(n) `IS` | U(n) `GS` and `IA` passed |
| `TU` track | U4 `CS` passed |

Generalization / improvisation levels draw from **all unlocked content** up to that unit
(cells in `cells.json` filtered by `minContent` and meter), not only from that unit.

## 4. Mastery and review

Tracked per `(patternId, level)` for familiar-pattern levels, and per `(unitId, level)` for
inference levels (which use generated patterns).

**Attempt pass** — defined per exercise in `04-exercises.md`.

**Level passed for a unit** when both:
- every pattern of the unit has ≥ 2 evaluation-mode passes, on ≥ 2 different calendar days;
- rolling accuracy over the last 12 evaluation attempts at that unit/level ≥ 85 %.

For inference levels: ≥ 15 evaluation attempts over ≥ 2 days with rolling accuracy ≥ 80 %.

**Review scheduler** — Leitner boxes per item, intervals `1, 2, 4, 8, 16, 32` days.
- Pass → move up one box. Fail → box 1.
- Two consecutive fails at a symbolic/inference level → schedule a **bridge**: the same pattern
  at the previous aural level (e.g. fail `SA` reading of `D-EL-03` twice → `VA` echo of `D-EL-03`
  next session). This implements MLT bridging.
- Passed levels are never re-locked; they just get review items.

All thresholds are constants in `MasteryPolicy` (single file).

## 5. Session structure

Default length 12 min (setting: 5–30). The session planner fills slots in this order:

| Slot | Share | Content |
|---|---|---|
| Warm-up | ~1 min | Movement prompt (text) + pulse-hold drill in a known meter (`04-exercises.md` → E10) |
| Review | ≤ 40 % | Due Leitner items, oldest first, mixed meters |
| New | ≥ 45 % | Frontier: lowest unpassed level of the earliest unit that has one; teaching mode first, then evaluation mode |
| Audiation drill | ~1 min | Pulse-hold or "continue the pattern silently" (E10/E11) |
| Summary | — | What passed, what is due tomorrow |

Rules:
- Group items by meter in blocks of ≥ 3, re-establishing meter (count-in) at each block change.
- Never more than 2 new patterns introduced per session per unit (teaching mode).
- Teaching mode for a pattern: echoed with support (click stage A, syllables at VA) until it is correct,
  at most `MasteryPolicy.maxTeachingAttempts` (4) tries → then it enters the evaluation pool.
- Every tap attempt is its own short block (count-in → prompt → hold → response) followed at once by a
  yes/no verdict.

## 6. Click (metronome) fading

The click is scaffolding. Its availability depends on the level:

| Stage | Click | Used for |
|---|---|---|
| A | Macro + micro beats | `AO`, `VA` teaching mode |
| B | Macrobeats only | `AO`, `VA` evaluation; `PS`; `SA` |
| C | Count-in only (one measure), then silence | `CS`, `GA`, `GV`, `GS`, `IA`, `IS` |
| D | Count-in, then silence, longer stretches | Pulse-hold drills, review of passed items |

Setting: "Always allow click" (on = learner may force stage B; such attempts do not count toward
mastery of stage-C levels).

## 7. Tempo

Tempo is macrobeat BPM.

| Meter | Default | Range in generalization |
|---|---|---|
| Usual duple / combined | 80 | 66–96 |
| Usual triple | 56 | 46–66 |
| Unusual (per microbeat eighth) | eighth = 200 | 168–232 |

Teaching mode plays at `TempoPolicy.teachingFactor` (85 %) of the default and slows by
`TempoPolicy.retryFactor` (5 %) after each miss, never below the range's lower bound (the slowest tempo
at which the macrobeat is still felt as the pulse). Evaluation always uses the default tempo, so mastery
results stay comparable.

In inference levels, tempo is randomized within range per block so the learner does not bind
patterns to one tempo. **[uncertain]** These defaults are pragmatic, not from Gordon.
