# 03 — Rhythm model

All rhythm logic lives in `AudiateCore` (pure Swift). `tools/build_patterns.py` implements the same
rules in Python; the Swift implementation must produce identical results for every pattern in
`patterns.json` (this is a unit test).

## 1. Time representation

- `ticksPerMicrobeat = 12` (divisible by 2 for divisions and allows thirds of a 2-microbeat
  macrobeat: 24 / 3 = 8).
- A **meter** is an ordered list of macrobeat sizes in microbeats:
  duple `[2,2]`, triple `[3,3]`, 5/8 `[2,3]` or `[3,2]`, 7/8 `[2,2,3]` etc.
- A **pattern** = one measure (body) + optional pickup (negative ticks, before the barline).
- An **event** = `{ startTick, ticks, kind: note | rest | continuation, tieToNext }`.
  `continuation` = tied-into note (no onset).

```swift
struct Meter: Codable, Hashable { let id: String; let macrobeats: [Int]; let allowsThirds: Bool }
enum EventKind: String, Codable { case note, rest, continuation }
struct RhythmEvent: Codable, Hashable {
    let startTick: Int; let ticks: Int; let kind: EventKind; let tieToNext: Bool
}
struct Pattern: Codable, Identifiable {
    let id: String; let meter: Meter; let content: ContentKind
    let pickupTicks: Int; let events: [RhythmEvent]
}
```

Conversion to seconds: `seconds = ticks / ticksPerMicrobeat * microbeatDuration`, where
`microbeatDuration = 60 / (macroBPM * microbeatsInThatMacrobeat)` for usual meters, and
`60 / eighthBPM` for unusual meters (microbeat = eighth note, constant).

## 2. Syllable derivation

```
syllable(meter, tick):
    tick = tick mod measureTicks            // handles pickups (negative ticks)
    find macrobeat (start s, size n) containing tick
    off = tick - s
    if off % 12 == 0:  return microSyllables(meter, n)[off / 12]
    if off % 12 == 6:  return "ta"
    if meter.allowsThirds and n == 2 and off in {8, 16}: return ["Du","da","di"][off / 8]
    error "not on syllable grid"

microSyllables(meter, n):
    usual meters:   n == 2 -> [Du, de];  n == 3 -> [Du, da, di]
    unusual meters: n == 2 -> [Du, be];  n == 3 -> [Du, ba, bi]
```

Display form per event kind: note → `Du`, rest → `(Du)`, continuation → `[Du]`.
Elongation is implicit (a note with long `ticks`); UI may render it as `Du—`.

Syllables are in `SyllableTable` (one file) — see the **[uncertain]** note in `01-methodology.md` §3.

## 3. Notation mapping

The meter defines a reference unit:

| Meter | Time signature | 24 ticks = |
|---|---|---|
| usual duple, usual combined | 2/4 | quarter (macrobeat = quarter) |
| usual triple, unusual | 6/8, 5/8, 7/8 | quarter (microbeat = eighth = 12 ticks) |

In every supported meter a microbeat (12 ticks) is notated as an eighth, so one table covers all:

| Ticks | Value | Notes |
|---|---|---|
| 72 | dotted half | |
| 48 | half | |
| 36 | dotted quarter | |
| 24 | quarter | |
| 18 | dotted eighth | |
| 12 | eighth | |
| 8 | eighth, tuplet 3 | combined meter only |
| 6 | sixteenth | |

`patterns.json` already contains `notation: {value, dots, tuplet}` per event; the Swift side
re-derives it and the test compares.

**Beaming:** beam consecutive notes of value ≤ eighth that lie inside the same macrobeat.
Rests break beams. Triplet groups get a bracket with "3".

**Ties:** draw a curve from a note with `tieToNext` to the following `continuation`.

## 4. Notation rendering

- Single-line percussion staff, stems up, SwiftUI `Canvas` + Bravura (SMuFL) glyphs.
- Required glyphs (SMuFL code points; verify against `bravura_metadata.json`):
  noteheadBlack U+E0A4, noteheadHalf U+E0A3, augmentationDot U+E1E7,
  restHalf U+E4E4, restQuarter U+E4E5, rest8th U+E4E6, rest16th U+E4E7,
  flag8thUp U+E240, flag16thUp U+E242, timeSig0–9 U+E080–U+E089, tuplet3 U+E883.
- Horizontal spacing proportional to `ticks` with a minimum glyph width (rhythmic spacing).
- Optional syllable row under the staff (toggle; hidden in evaluation mode for symbolic levels).
- Playhead: thin vertical line moved in sync with audio during reading exercises (toggle).

## 5. Pattern generator (unfamiliar patterns)

Used by inference levels (`GA`, `GV`, `GS`, `IA` prompts).

```
generate(meter, unlockedContent, rng):
    for each macrobeat size n in meter.macrobeats:
        choose a cell from cells[n] where cell.minContent ∈ unlockedContent
            (weights: macro_micro 1, newer content 2)
    reject if result equals any pattern in patterns.json (must be unfamiliar)  // GA mixes both
    reject if every macrobeat is a rest
    optionally (if 'tie' unlocked, p = 0.15): tie last note of macrobeat k to first note of k+1
        when both are notes and the pair is notatable
    optionally (if 'upbeat' unlocked, p = 0.2): prepend a pickup of 6 or 12 ticks
```

`combined` cells (`8 8 8`) are allowed only in `usual_combined` meter.

## 6. Difficulty heuristic

```
score = 0.4·onsets + 0.5·(onsets off the microbeat grid) + 1.5·(syncopated onsets)
      + contentWeight {macro_micro 0, division 1, elongation 1.5, rest 1.5, tie 2, upbeat 2}
easy < 2.5 ≤ moderate < 4.5 ≤ difficult
```
Syncopated = onset on a weaker grid point than a grid point it sustains through
(strength: macrobeat 3, microbeat 2, division 1). Used only for ordering within a unit:
teach easy → moderate → difficult.
