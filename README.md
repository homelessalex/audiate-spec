# Audiate

A native macOS rhythm trainer built on the **rhythm** half of Edwin Gordon's Music Learning Theory (MLT),
for one adult learning on their own. You learn rhythm patterns by ear first, then connect them to
notation, then read, write and improvise patterns you have never seen.

*"Audiate" is a working name. A personal project in active development, made by its own learner.*

## The idea

Most rhythm apps start from the page: see a figure, tap it. MLT turns that around. You first build a
vocabulary of rhythms by ear, *audiate* them (hear them inside, with no sound around), and only then learn
what they look like. Reading means hearing the page before you play it, not working out note values.

The app keeps to a few rules that come from the method:

- **Sound before sight.** A unit's notation doesn't appear until you have echoed its patterns by ear.
- **Meter first.** Every pattern comes after a count-in in its meter. Nothing is played "cold".
- **One pulse.** A whole session runs on one uninterrupted metronome: listen, hold it, answer, see the
  verdict while the next count-in ticks. The app never waits for you to start.
- **Timing against the audio clock.** Taps are timestamped by the system, latency-compensated and graded
  against the clock the sound is played on, never against UI timers.

## What you practise

The content is 12 units: duple and triple meters, divisions, elongations, rests, ties, upbeats, triplets,
5/8 and 7/8. Each unit climbs the skill levels of Gordon's learning sequence:

| Level | You… |
|---|---|
| **AO** · aural | echo patterns by ear |
| **VA** · notation association | echo with the notation in view; pick the notation you heard |
| **PS** · partial synthesis | hear a series of patterns and name the meter |
| **SA** · symbolic | read familiar patterns, take dictation |
| **CS** · composite synthesis | read series, find the meter from notation alone |
| **GA / GV / GS** · generalization | the same with unfamiliar, generated patterns |
| **IA / IS** · improvisation | answer with a different pattern, compose your own and play it |

Plus:

- **Phrase reading**: 2–4 familiar patterns, mixed from every unit you know, read measure after measure
  without stopping. A ladder of length × tempo; every measure reviewed against your taps. Endless on demand.
- **Pulse trainer**: the click drops out for longer and longer stretches (or at random), and you see how
  far you drifted when it comes back.
- **Two-hand mode**: one hand keeps the beat, the other plays the rhythm. MIDI keyboards work as well.
- **Mastery and review**: a level counts once every pattern has passed on two different days. Spaced
  review (Leitner) and a step back to the ear level after repeated misses.

Input is the computer keyboard, the trackpad or a MIDI keyboard. No voice: patterns play on an open hi-hat,
choked at the end of each note so you hear durations.

## Download

A ready-to-run build is on the [Releases](https://github.com/homelessalex/audiate-spec/releases) page:
open the `.dmg` and drag Audiate to Applications. macOS 14 or later, Apple Silicon or Intel.

The build is not notarized by Apple (no paid developer account), so the first launch is blocked with
"Apple could not verify Audiate…". Allow it once:

- **macOS 15 and later:** try to open Audiate, then System Settings → Privacy & Security → scroll down →
  *Open Anyway* next to the Audiate message, and confirm.
- **macOS 14:** right-click Audiate in Applications → *Open* → *Open*.

Or, in Terminal: `xattr -dr com.apple.quarantine /Applications/Audiate.app`.

After that it opens normally. Calibrate once per output device (main window → Calibrate…).

## Building

Requirements: macOS 14+, Xcode 16 (Swift 6, strict concurrency). No third-party dependencies.

```sh
open Audiate.xcodeproj        # run the Audiate scheme
```

`Audiate.xcodeproj` is generated from `project.yml` ([XcodeGen](https://github.com/yonaskolb/XcodeGen)).
Regenerate it only when `project.yml` changes: `xcodegen generate`.

Tests:

```sh
cd Packages/AudiateCore && swift test     # rhythm model, grading, planning, flow
cd Packages/AudiateAudio && swift test    # sample-exact timing through AVAudioEngine
```

Calibrate once per output device (main window → Calibrate…) so taps line up with what you hear.

## Layout

| Path | What |
|---|---|
| `Packages/AudiateCore` | Pure Swift domain logic, no UI or audio imports: rhythm model, syllables, notation layout, pattern generator, graders, session planner, the session flow (`FlowSequencer`), mastery and review |
| `Packages/AudiateAudio` | AVAudioEngine playback on its own queue, sample-accurate scheduling, key and MIDI input, latency compensation |
| `App` | SwiftUI app, SwiftData persistence, the staff renderer (Bravura via CoreText) |
| `data` | Pattern library, macrobeat cells and curriculum, generated. Don't edit by hand |
| `tools` | `build_patterns.py` (source of truth for the library), sample synthesis |
| `docs` | The spec the app is built from |

## Documentation

1. [Methodology](docs/01-methodology.md): MLT rhythm theory condensed, and where the app deliberately deviates
2. [Curriculum](docs/02-curriculum.md): units × levels, gates, mastery, sessions, tempo
3. [Rhythm model](docs/03-rhythm-model.md): ticks, syllable derivation, notation mapping, generator
4. [Exercises](docs/04-exercises.md): every exercise, its flow, grading and pass criteria
5. [Architecture](docs/05-architecture.md): modules, audio timing, input, rendering, testing
6. [Roadmap](docs/06-roadmap.md): milestones and status
7. [Timing verification](docs/timing-verification.md): how audio timing was measured

## Credits

- Edwin E. Gordon, *Learning Sequences in Music*, and the Gordon Institute for Music Learning, for the
  method. This app is an independent interpretation, not affiliated with or endorsed by GIML.
- [Bravura](https://github.com/steinbergmedia/bravura) music font by Steinberg, under the SIL Open Font
  License (`Resources/Fonts/Bravura-OFL.txt`).
- Percussion samples are synthesized by `tools/synth_samples.py`.
