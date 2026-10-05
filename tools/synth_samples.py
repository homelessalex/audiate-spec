#!/usr/bin/env python3
"""
Synthesizes the percussion samples (stdlib only) as mono 16-bit WAV at 44.1 kHz.
Called by tools/make_samples.sh, which converts them to CAF.

  hihat_open   prompt notes; long (3.5 s) so the player can choke it at the note's end
  beat_strong  metronome / count-in on macrobeats: crisp 1 kHz tick, louder than beat_weak
  beat_weak    metronome / count-in on microbeats: short crisp tick, quieter than beat_strong
  tap          learner's key press feedback

Every sample starts its attack at sample 0. [uncertain] Timbres are a first pass; tune by ear.
"""
import math, os, random, struct, sys, wave

RATE = 44100


def write(path, samples, peak_dbfs):
    peak = max(abs(v) for v in samples) or 1
    gain = 10 ** (peak_dbfs / 20) / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(struct.pack("<%dh" % len(samples),
                                  *(max(-32768, min(32767, int(round(v * gain * 32767)))) for v in samples)))


def highpass(x, cutoff):
    rc = 1 / (2 * math.pi * cutoff); dt = 1 / RATE; a = rc / (rc + dt)
    y, prev_x, prev_y = [], 0.0, 0.0
    for v in x:
        prev_y = a * (prev_y + v - prev_x); prev_x = v
        y.append(prev_y)
    return y


def hihat_open(seconds=3.5, decay=0.9):
    # 808-style: six inharmonic square waves + a little noise, high-passed, exponential decay.
    freqs = [205.3, 304.4, 369.6, 522.7, 540.0, 800.0]
    ratio = 2.6  # move the metallic cluster up
    rng = random.Random(7)
    n = int(seconds * RATE)
    raw = []
    for i in range(n):
        t = i / RATE
        metal = sum(1.0 if math.sin(2 * math.pi * f * ratio * t) >= 0 else -1.0 for f in freqs) / len(freqs)
        raw.append(0.7 * metal + 0.3 * rng.uniform(-1, 1))
    filtered = highpass(highpass(raw, 6000), 6000)
    out = []
    for i, v in enumerate(filtered):
        t = i / RATE
        attack = min(1.0, t / 0.001)
        out.append(v * attack * math.exp(-t / decay))
    tail = int(0.05 * RATE)  # end at true silence
    for i in range(tail):
        out[n - tail + i] *= 1 - (i + 1) / tail
    return out


def beat_strong(seconds=0.04):
    # Accent: same kind of crisp tick as beat_weak, lower (1 kHz), longer decay (7 ms), louder.
    # No pitch sweep: a falling thump sounded doubled on small speakers.
    rng = random.Random(2)
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        tone = math.sin(2 * math.pi * 1000 * t) * math.exp(-t / 0.007)
        edge = rng.uniform(-1, 1) * 0.5 * math.exp(-t / 0.0007)
        out.append(tone + edge)
    return out


def beat_weak(seconds=0.03):
    # Short crisp tick: 1.8 kHz with a 4 ms decay plus a 1 ms noise transient for a sharp edge.
    rng = random.Random(3)
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        tone = math.sin(2 * math.pi * 1800 * t) * math.exp(-t / 0.004)
        edge = rng.uniform(-1, 1) * 0.5 * math.exp(-t / 0.0007)
        out.append(tone + edge)
    return out


def tap(seconds=0.015):
    rng = random.Random(1)
    return [rng.uniform(-1, 1) * math.exp(-(i / RATE) / 0.003) for i in range(int(seconds * RATE))]


if __name__ == "__main__":
    out = sys.argv[1]
    write(os.path.join(out, "hihat_open.wav"), hihat_open(), -4)
    write(os.path.join(out, "beat_strong.wav"), beat_strong(), -3)
    write(os.path.join(out, "beat_weak.wav"), beat_weak(), -14)
    write(os.path.join(out, "tap.wav"), tap(), -10)
