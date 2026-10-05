#!/usr/bin/env python3
"""
Helper for tools/make_samples.sh (stdlib only).

  process_sample.py trim  <in.wav> <out.wav>   trim leading silence (< -40 dBFS), cut to <= 250 ms,
                                                fade out, normalize peak to -3 dBFS
  process_sample.py click <out.wav> hi|lo|tap   synthesize a click

Input/output: mono 16-bit PCM WAV at 44.1 kHz.
"""
import math, random, struct, sys, wave

RATE = 44100
THRESHOLD_DBFS = -40.0
MAX_SECONDS = 0.25
FADE_SECONDS = 0.04
PEAK_DBFS = -3.0


def read(path):
    with wave.open(path, "rb") as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2 and w.getframerate() == RATE, path
        raw = w.readframes(w.getnframes())
    return [s / 32768.0 for s in struct.unpack("<%dh" % (len(raw) // 2), raw)]


def write(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(struct.pack("<%dh" % len(samples),
                                  *(max(-32768, min(32767, int(round(s * 32767)))) for s in samples)))


def trim(src, dst):
    s = read(src)
    threshold = 10 ** (THRESHOLD_DBFS / 20)
    start = next((i for i, v in enumerate(s) if abs(v) >= threshold), 0)
    s = s[start:start + int(MAX_SECONDS * RATE)]
    fade = min(len(s), int(FADE_SECONDS * RATE))
    for i in range(fade):
        s[len(s) - fade + i] *= 1 - (i + 1) / fade
    peak = max((abs(v) for v in s), default=0) or 1
    gain = 10 ** (PEAK_DBFS / 20) / peak
    write(dst, [v * gain for v in s])


def click(dst, kind):
    freq, amp, dur, decay = {"hi": (2000, 0.7, 0.03, 0.006),
                             "lo": (1200, 0.45, 0.03, 0.005),
                             "tap": (0, 0.35, 0.015, 0.003)}[kind]
    rng = random.Random(1)
    n = int(dur * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t / decay)
        tone = math.sin(2 * math.pi * freq * t) if freq else rng.uniform(-1, 1)
        out.append(amp * env * tone)
    write(dst, out)


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "trim":
        trim(sys.argv[2], sys.argv[3])
    elif cmd == "click":
        click(sys.argv[2], sys.argv[3])
    else:
        sys.exit(__doc__)
