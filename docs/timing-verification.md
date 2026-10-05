# Timing verification (M1)

## How blocks are played

`Timeline` (AudiateCore) lists every sound of a block in seconds. `BlockMixer` renders the whole
block into **one** mono buffer, each sample placed at `round(time × sampleRate)`. `BlockPlayer`
schedules that buffer on one `AVAudioPlayerNode` and starts it at a host time 150 ms ahead
(`BlockClock` anchor). Relative timing inside a block is therefore sample-accurate by construction;
nothing is scheduled from UI timers.

This deviates from the "pool of player nodes" sketch in `05-architecture.md` §3 for that reason.
The pool is unnecessary for pre-mixed blocks; a second node plays the immediate tap sound.

## Automated check (runs with `swift test` in Packages/AudiateAudio)

`BlockTimingTests`:
- `mixerPlacesSoundsOnExactFrames`: onsets detected in the mixed buffer equal the scheduled frames.
- `engineRenderKeepsClickJitterUnderOneMillisecond`: the mixed block is played through
  `AVAudioPlayerNode → mainMixer` in **offline manual rendering** (44.1 → 48 kHz resampling included),
  click onsets are detected (threshold 0.05 after ≥ 10 ms of silence) and their deviation from the
  scheduled times, minus the constant offset, must stay < 1 ms. D-DV-03 @ 80, T-MM-04 @ 56,
  UU-MM-02 @ eighth = 200, click stage A, three patterns per block.

## Manual loopback check on hardware (optional)

1. Connect the headphone output to a line input with a cable (or use an aggregate device with
   BlackHole as output and record from it).
2. Open the Debug Player (⇧⌘D), choose D-DV-03, 80 BPM, click stage A, 6 patterns, and press Play
   while recording the input in Audacity/QuickTime at 48 kHz.
3. In the recording, mark the click onsets (Audacity: Analyze → Label Sounds, threshold −30 dB).
   Export the labels, compute inter-onset intervals, compare with 0.375 s (eighths at 80 BPM).
   Max |IOI − 0.375 s| must be < 1 ms.

## Acceptance check: tapping along (manual, wired output)

1. Main window → Calibrate… → Start, tap Space with the clicks. The offset is saved per output device.
2. ⇧⌘D → D-DV-03, 80 BPM, stage B → Play. Echo the pattern with Space in the measure after the
   prompt. The report shows PASS/FAIL, hits/misses/extras and per-onset errors (also printed to stdout).

**[verify on device]** `NSEvent.timestamp` and host time are assumed to share the mach clock.
If they don't, the calibration median absorbs a constant offset; check that the per-onset errors in the
Debug Player center near 0 ms after calibration.
