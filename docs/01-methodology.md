# 01 — Methodology: Gordon's MLT, rhythm part

This is the condensed theory the app implements. It is a working summary, not a substitute for
Gordon's own texts. Items marked **[uncertain]** could not be confirmed from primary sources while
writing this spec; they are isolated in code as constants/settings.

Primary sources (for the human, not needed for coding):
- Edwin E. Gordon, *Learning Sequences in Music: A Contemporary Music Learning Theory* (GIA).
- Gordon & Grunow & Azzara, *Jump Right In* teacher materials (GIA).
- The Gordon Institute for Music Learning (giml.org).

## 1. Audiation

Audiation = hearing and comprehending music in the mind when the sound is not physically present
(including when reading or writing notation). The goal of the app is not "tap what you see" but
"hear in your head what you see, then perform it". Imitation alone is not audiation; the learner
must hold the meter internally and understand the *function* of each sound in it.

Consequences for the app:
- The learner's internal pulse is trained explicitly (exercises where the click disappears).
- Syllables name the **function** of a sound within the meter, not its note value.
- Reading is taught only after the patterns are already known by ear and by syllable.

## 2. Rhythm structure

Gordon describes rhythm in three layers:

| Layer | Meaning | In the app |
|---|---|---|
| **Macrobeats** | The large, felt pulse | Count-in, optional click, left-hand key in two-hand mode |
| **Microbeats** | Equal subdivisions of macrobeats (2 or 3 per macrobeat) | Defines meter type |
| **Melodic rhythm** | The actual rhythm pattern | What the learner echoes, reads, writes |

### Meter classification

| Meter | Structure | Notation used by the app |
|---|---|---|
| Usual duple | Equal macrobeats, each divided into 2 microbeats | 2/4 (macrobeat = quarter) |
| Usual triple | Equal macrobeats, each divided into 3 microbeats | 6/8 (macrobeat = dotted quarter) |
| Usual combined | Duple and triple divisions of the same macrobeat within one pattern | 2/4 with triplets |
| Unusual paired | Two **unequal** macrobeats (2+3 or 3+2 microbeats) | 5/8 |
| Unusual unpaired | Three unequal macrobeats (e.g. 2+2+3) | 7/8 |

Gordon also defines intact unusual meters, multimetric and multitemporal music. Out of scope for v1.

Note: in MLT the same audiated meter can be written in many time signatures (2/4, 2/2, 6/8…).
The app uses one notation per meter until the theory level (see curriculum), where alternative
time signatures are introduced.

### Rhythm functions (content), in teaching order

1. Macrobeats and microbeats
2. Divisions (subdivision of a microbeat)
3. Elongations (a sound sustained longer than a microbeat/macrobeat)
4. Rests
5. Ties
6. Upbeats (pattern begins before the first macrobeat)

Order of meters: usual duple → usual triple → usual combined → unusual paired → unusual unpaired.

## 3. Beat-function syllables

Syllables are chosen by **position within the macrobeat**, not by note value.

| Position | Usual duple | Usual triple | Unusual: 2-microbeat macrobeat | Unusual: 3-microbeat macrobeat |
|---|---|---|---|---|
| Macrobeat | Du | Du | Du | Du |
| Microbeats | Du de | Du da di | Du be | Du ba bi |
| Division (half a microbeat) | ta | ta | ta | ta |
| Third of a duple macrobeat (combined) | Du da di | — | — | — |

Examples: duple eighths `Du de Du de`; duple sixteenths `Du ta de ta`; triple 6/8 eighths
`Du da di`; 6/8 sixteenths `Du ta da ta di ta`; 5/8 (2+3) `Du be Du ba bi`; 7/8 (2+2+3)
`Du be Du be Du ba bi`.

- **Elongation:** the syllable of the onset is sustained (`Du—`). No new syllable for sustained time.
- **Rest:** the syllable of the rest's position is audiated silently (the app shows it as `(de)`).
- **Tie:** the tied-into note has no new onset; app shows its position syllable in brackets `[Du]`.
- **Upbeat:** gets the syllable of its position before the barline (e.g. `de Du`).

**[uncertain]** Gordon revised some division syllables over time (e.g. the 2003 change for triplet
subdivisions inside triple meter). Unusual-meter syllables `be` / `ba bi` match common MLT practice
but should be double-checked against *Jump Right In*. All syllables live in one table in
`AudiateCore` (`SyllableTable`) so they can be swapped.

## 4. Skill Learning Sequence

Two categories. Each content unit is taken through them in order.

### Discrimination learning (rote: learner is taught)

| Level | Code | What the learner does |
|---|---|---|
| Aural/Oral | `AO` | Hears a pattern on a neutral syllable ("bah"\*), echoes it |
| Verbal Association | `VA` | Hears and echoes patterns **with rhythm syllables**; names meter |
| Partial Synthesis | `PS` | Hears a *series* of familiar patterns, identifies the meter (context) |
| Symbolic Association | `SA` | Reads and writes familiar patterns individually |
| Composite Synthesis | `CS` | Reads and writes series of familiar patterns; identifies meter/time signature |

### Inference learning (learner generalizes from what they know)

| Level | Code | What the learner does |
|---|---|---|
| Generalization — aural/oral | `GA` | Hears familiar + unfamiliar patterns; same/different; echoes unfamiliar on "bah" |
| Generalization — verbal | `GV` | Hears unfamiliar patterns on "bah", answers with syllables |
| Generalization — symbolic | `GS` | Reads and writes **unfamiliar** patterns |
| Creativity/Improvisation — aural/oral | `IA` | Answers a pattern with a *different* pattern in the same meter |
| Creativity/Improvisation — symbolic | `IS` | Writes own patterns, then performs them |
| Theoretical understanding | `TU` | Note values, time signatures, alternative notations of the same meter |

\* Gordon's neutral syllable is "bah". It sounds almost like the unusual-meter syllable "ba", so the
app's neutral sample is "bum" by default (setting). Everywhere in these docs "bah" = the neutral syllable.

Gordon allows "bridging" (moving back and forth between levels, e.g. VA ↔ GA). The app does this
automatically through review (see curriculum §4).

## 5. Pattern instruction format

- Short sessions (Gordon: ~5–10 min of pattern instruction per lesson). The app defaults to
  10–15 min including review.
- **Teaching mode**: the pattern is presented and echoed several times with support
  (syllables visible, slower tempo allowed).
- **Evaluation mode**: the learner performs alone, once, without support; this is what is graded
  for mastery.
- Meter and tempo are established before every pattern block (count-in in the pattern's meter).
- Patterns are presented without pitch (unpitched voice/percussion).
- Patterns are graded easy / moderately difficult / difficult. Gordon derived these empirically;
  the app uses a heuristic score instead **[uncertain: not Gordon's own classification]**.

## 6. Movement

MLT treats bodily movement (Laban: flow, weight, space, time) as the basis of rhythm audiation —
continuous flowing movement first, then macrobeats (e.g. heels/body weight) and microbeats (hands).

An app cannot grade movement. It does:
- show short movement prompts at session start ("sway on macrobeats for 8 beats");
- offer **two-hand mode**: one key keeps macrobeats while the other taps the melodic rhythm —
  the closest keyboard equivalent of "feel the macrobeat in the body, perform the rhythm".

## 7. Adaptations for a self-taught adult (deliberate deviations)

| Gordon (classroom) | App | Reason |
|---|---|---|
| Teacher judges the response | Algorithmic onset grading | No teacher |
| Learner chants syllables aloud | Learner chants aloud (not graded) + taps; syllable *recognition* is graded via choice tasks | Keyboard-only input |
| Group then individual | Teaching mode then evaluation mode | Single user |
| Teacher chooses next patterns | Mastery + spaced review scheduler | Self-paced |
| No metronome; meter is felt | Click is a scaffold that fades out by level | Adults without a teacher drift; fading keeps the goal of internal pulse |
