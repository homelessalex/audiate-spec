# Audiate — rhythm trainer based on Gordon's Music Learning Theory

Native macOS app that guides one adult learner through the **rhythm** part of Edwin Gordon's
Music Learning Theory (MLT): build a vocabulary of rhythm patterns by ear, attach beat-function
syllables, then connect them to notation, then read/write/improvise unfamiliar patterns.

The working name "Audiate" is a placeholder.

## Read before writing code

| File | What it defines |
|---|---|
| `docs/01-methodology.md` | MLT rhythm theory condensed; the rules the app must not violate |
| `docs/02-curriculum.md` | Units (content) × skill levels, unlock gates, session structure |
| `docs/03-rhythm-model.md` | Tick model, syllable derivation, notation mapping, pattern generator |
| `docs/04-exercises.md` | Every exercise type: flow, input, grading, pass criteria |
| `docs/05-architecture.md` | Tech stack, modules, audio timing, input, rendering, persistence, tests |
| `docs/06-roadmap.md` | Milestones with acceptance criteria — implement in this order |
| `data/patterns.json` | Pattern library, generated — do not hand-edit |
| `data/cells.json` | Macrobeat cells for generating unfamiliar patterns |
| `tools/build_patterns.py` | Source of truth for the library; edit and re-run to extend |

## Fixed decisions

- Platform: macOS 14+, Swift 6 (strict concurrency), SwiftUI, SwiftData. No third-party dependencies
  except the Bravura music font (SIL OFL), bundled as a resource.
- Scope: rhythm only. No tonal/pitch content.
- Input: computer keyboard (and trackpad click as a secondary). MIDI is a later, optional milestone.
- UI language: English only.
- Single user, local only. No accounts, no network, no analytics.

## Non-negotiable rules (from the methodology)

1. **Sound before sight — per pattern.** A pattern's notation is never shown before the learner has
   heard and echoed that pattern by ear (its `AO` teaching echoes). Ear exercises (echo, name the
   syllables) never show notation. Reading follows in the same lesson. This deliberately relaxes Gordon's
   per-unit order (`docs/01-methodology.md` §7); gates in `docs/02-curriculum.md` §3.
2. **Meter context first.** Every pattern is preceded by an established meter and tempo
   (preparatory count-in in the pattern's meter). Never present a pattern "cold".
3. **Echo in time.** Responses happen in the measure(s) right after the prompt, without stopping
   the pulse. The app never waits for the user to start. A silent "hold it" measure between prompt and
   response is allowed (the pulse goes on); its length is one constant (`EchoPolicy.gapMeasures`).
4. **Syllables are derived, never stored by hand.** Use the algorithm in `docs/03-rhythm-model.md`.
5. **Timing is measured against the audio clock**, with latency compensation. Never against UI
   timers or `Date()`.

## Code conventions

- Domain logic (rhythm model, syllables, grading, scheduling of exercises, mastery) lives in a
  pure Swift package `AudiateCore` with no AppKit/SwiftUI/AVFoundation imports, fully unit-tested.
- Audio and input live in `AudiateAudio`; UI in the app target.
- Every grading function is deterministic and has table-driven tests built from `patterns.json`.
- Keep files small; one type per file where reasonable.
- When something in the docs is marked **[uncertain]**, implement it behind a setting or a single
  constant so it can be changed without refactoring.
