#!/usr/bin/env python3
"""
Builds data/patterns.json and data/cells.json from the compact definitions below.
Validates every pattern (measure length, notatable durations, derivable syllables).

Run:  python3 tools/build_patterns.py
Edit the PATTERNS / CELLS tables to extend the library, then re-run.

Compact token syntax (durations in ticks, TPM = 12 ticks per microbeat):
  "12"    note, 12 ticks
  "r12"   rest, 12 ticks
  "12~"   note tied INTO the next token (next token is a continuation, no new onset)
Pattern fields: id, meter, content, tokens, optional pickup (tokens before the barline).
"""
import json, os, sys

TPM = 12  # ticks per microbeat

# ---------------------------------------------------------------- meters
METERS = {
    "usual_duple":     {"macro": [2, 2],    "notation": "2/4", "unit": "quarter", "allowThirds": False},
    "usual_triple":    {"macro": [3, 3],    "notation": "6/8", "unit": "eighth",  "allowThirds": False},
    "usual_combined":  {"macro": [2, 2],    "notation": "2/4", "unit": "quarter", "allowThirds": True},
    "unusual_paired_2_3":   {"macro": [2, 3],    "notation": "5/8", "unit": "eighth", "allowThirds": False},
    "unusual_paired_3_2":   {"macro": [3, 2],    "notation": "5/8", "unit": "eighth", "allowThirds": False},
    "unusual_unpaired_2_2_3": {"macro": [2, 2, 3], "notation": "7/8", "unit": "eighth", "allowThirds": False},
    "unusual_unpaired_3_2_2": {"macro": [3, 2, 2], "notation": "7/8", "unit": "eighth", "allowThirds": False},
    "unusual_unpaired_2_3_2": {"macro": [2, 3, 2], "notation": "7/8", "unit": "eighth", "allowThirds": False},
}

def micro_syllables(meter_id, macro_size):
    unusual = meter_id.startswith("unusual")
    if macro_size == 2:
        return ["Du", "be"] if unusual else ["Du", "de"]
    if macro_size == 3:
        return ["Du", "ba", "bi"] if unusual else ["Du", "da", "di"]
    raise ValueError(macro_size)

# notation value tables: ticks -> (base value, dots, tuplet)
QUARTER_BASED = {48: ("half", 0, None), 36: ("quarter", 1, None), 24: ("quarter", 0, None),
                 18: ("eighth", 1, None), 12: ("eighth", 0, None), 6: ("16th", 0, None),
                 8: ("eighth", 0, 3)}
EIGHTH_BASED = {72: ("half", 1, None), 48: ("half", 0, None), 36: ("quarter", 1, None),
                24: ("quarter", 0, None), 18: ("eighth", 1, None), 12: ("eighth", 0, None),
                6: ("16th", 0, None)}

# ---------------------------------------------------------------- content
# content ids follow the Rhythm Content Learning Sequence (see docs/02-curriculum.md)
PATTERNS = [
    # ---------- usual duple (2 macrobeats = 48 ticks)
    ("D-MM-01", "usual_duple", "macro_micro", "24 24"),
    ("D-MM-02", "usual_duple", "macro_micro", "12 12 24"),
    ("D-MM-03", "usual_duple", "macro_micro", "24 12 12"),
    ("D-MM-04", "usual_duple", "macro_micro", "12 12 12 12"),
    ("D-DV-01", "usual_duple", "division", "6 6 12 24"),
    ("D-DV-02", "usual_duple", "division", "12 6 6 24"),
    ("D-DV-03", "usual_duple", "division", "6 6 6 6 24"),
    ("D-DV-04", "usual_duple", "division", "24 6 6 6 6"),
    ("D-DV-05", "usual_duple", "division", "6 6 12 6 6 12"),
    ("D-DV-06", "usual_duple", "division", "12 6 6 12 12"),
    ("D-EL-01", "usual_duple", "elongation", "48"),
    ("D-EL-02", "usual_duple", "elongation", "36 12"),
    ("D-EL-03", "usual_duple", "elongation", "12 24 12"),
    ("D-EL-04", "usual_duple", "elongation", "18 6 24"),
    ("D-EL-05", "usual_duple", "elongation", "18 6 18 6"),
    ("D-EL-06", "usual_duple", "elongation", "6 12 6 24"),
    ("D-RS-01", "usual_duple", "rest", "24 r24"),
    ("D-RS-02", "usual_duple", "rest", "r12 12 24"),
    ("D-RS-03", "usual_duple", "rest", "12 r12 12 12"),
    ("D-RS-04", "usual_duple", "rest", "6 6 r12 24"),
    ("D-TI-01", "usual_duple", "tie", "12 12~ 12 12"),
    ("D-TI-02", "usual_duple", "tie", "24~ 6 6 12"),
    ("D-UB-01", "usual_duple", "upbeat", "24 24", "12"),
    ("D-UB-02", "usual_duple", "upbeat", "24 24", "6 6"),
    ("D-UB-03", "usual_duple", "upbeat", "12 12 24", "6"),
    # ---------- usual triple (2 macrobeats = 72 ticks)
    ("T-MM-01", "usual_triple", "macro_micro", "36 36"),
    ("T-MM-02", "usual_triple", "macro_micro", "12 12 12 36"),
    ("T-MM-03", "usual_triple", "macro_micro", "36 12 12 12"),
    ("T-MM-04", "usual_triple", "macro_micro", "12 12 12 12 12 12"),
    ("T-DV-01", "usual_triple", "division", "6 6 12 12 36"),
    ("T-DV-02", "usual_triple", "division", "12 6 6 12 36"),
    ("T-DV-03", "usual_triple", "division", "12 12 6 6 36"),
    ("T-DV-04", "usual_triple", "division", "6 6 6 6 6 6 36"),
    ("T-DV-05", "usual_triple", "division", "36 6 6 12 12"),
    ("T-EL-01", "usual_triple", "elongation", "24 12 36"),
    ("T-EL-02", "usual_triple", "elongation", "24 12 24 12"),
    ("T-EL-03", "usual_triple", "elongation", "12 24 36"),
    ("T-EL-04", "usual_triple", "elongation", "72"),
    ("T-EL-05", "usual_triple", "elongation", "18 6 12 36"),
    ("T-RS-01", "usual_triple", "rest", "24 r12 36"),
    ("T-RS-02", "usual_triple", "rest", "r12 12 12 36"),
    ("T-RS-03", "usual_triple", "rest", "36 r36"),
    ("T-RS-04", "usual_triple", "rest", "12 r12 12 36"),
    ("T-TI-01", "usual_triple", "tie", "36~ 12 12 12"),
    ("T-TI-02", "usual_triple", "tie", "12 12 12~ 12 12 12"),
    ("T-UB-01", "usual_triple", "upbeat", "36 36", "12"),
    ("T-UB-02", "usual_triple", "upbeat", "24 12 36", "12 12"),
    ("T-UB-03", "usual_triple", "upbeat", "12 12 12 36", "6"),
    # ---------- usual combined (duple macrobeats divided in three)
    ("C-MM-01", "usual_combined", "macro_micro", "8 8 8 24"),
    ("C-MM-02", "usual_combined", "macro_micro", "24 8 8 8"),
    ("C-MM-03", "usual_combined", "macro_micro", "8 8 8 12 12"),
    ("C-MM-04", "usual_combined", "macro_micro", "12 12 8 8 8"),
    # ---------- unusual paired 5/8
    ("UP-MM-01", "unusual_paired_2_3", "macro_micro", "24 36"),
    ("UP-MM-02", "unusual_paired_2_3", "macro_micro", "12 12 12 12 12"),
    ("UP-MM-03", "unusual_paired_2_3", "macro_micro", "24 12 12 12"),
    ("UP-MM-04", "unusual_paired_2_3", "macro_micro", "12 12 36"),
    ("UP-DV-01", "unusual_paired_2_3", "division", "6 6 12 12 12 12"),
    ("UP-EL-01", "unusual_paired_2_3", "elongation", "24 24 12"),
    ("UP-MM-05", "unusual_paired_3_2", "macro_micro", "36 24"),
    ("UP-MM-06", "unusual_paired_3_2", "macro_micro", "12 12 12 12 12"),
    # ---------- unusual unpaired 7/8
    ("UU-MM-01", "unusual_unpaired_2_2_3", "macro_micro", "24 24 36"),
    ("UU-MM-02", "unusual_unpaired_2_2_3", "macro_micro", "12 12 12 12 12 12 12"),
    ("UU-MM-03", "unusual_unpaired_2_2_3", "macro_micro", "12 12 24 12 12 12"),
    ("UU-EL-01", "unusual_unpaired_2_2_3", "elongation", "24 12 12 36"),
    ("UU-MM-04", "unusual_unpaired_3_2_2", "macro_micro", "36 24 24"),
    ("UU-MM-05", "unusual_unpaired_2_3_2", "macro_micro", "24 36 24"),
]

# Macrobeat-sized building blocks for generating UNFAMILIAR patterns (generalization / improvisation).
# key = macrobeat size in microbeats (2 or 3); content = minimal content level that unlocks the cell.
CELLS = {
    "2": [
        ("24", "macro_micro"), ("12 12", "macro_micro"),
        ("6 6 12", "division"), ("12 6 6", "division"), ("6 6 6 6", "division"),
        ("18 6", "elongation"), ("6 12 6", "elongation"),
        ("r12 12", "rest"), ("12 r12", "rest"), ("r24", "rest"),
        ("8 8 8", "combined"),
    ],
    "3": [
        ("36", "macro_micro"), ("12 12 12", "macro_micro"),
        ("24 12", "elongation"), ("12 24", "elongation"),
        ("6 6 12 12", "division"), ("12 6 6 12", "division"), ("12 12 6 6", "division"),
        ("6 6 6 6 6 6", "division"), ("18 6 12", "elongation"),
        ("r12 12 12", "rest"), ("24 r12", "rest"), ("12 r12 12", "rest"),
    ],
}

# ---------------------------------------------------------------- logic
def parse(tokens):
    out = []
    for t in tokens.split():
        rest = t.startswith("r")
        tie = t.endswith("~")
        d = int(t.strip("r~"))
        out.append({"ticks": d, "rest": rest, "tieToNext": tie})
    return out

def macro_starts(meter_id):
    starts, s = [], 0
    for n in METERS[meter_id]["macro"]:
        starts.append((s, n)); s += n * TPM
    return starts, s

def syllable_at(meter_id, tick):
    starts, length = macro_starts(meter_id)
    tick %= length
    for s, n in starts:
        if s <= tick < s + n * TPM:
            off = tick - s
            if off % TPM == 0:
                return micro_syllables(meter_id, n)[off // TPM]
            if off % TPM == TPM // 2:
                return "ta"
            if METERS[meter_id]["allowThirds"] and n == 2 and off in (8, 16):
                return ["Du", "da", "di"][off // 8]
            raise ValueError(f"{meter_id}: tick {tick} not on a syllable grid")
    raise ValueError("unreachable")

def build_events(meter_id, events, start_tick):
    table = QUARTER_BASED if METERS[meter_id]["unit"] == "quarter" else EIGHTH_BASED
    t, prev_tied, res = start_tick, False, []
    for e in events:
        if e["ticks"] not in table:
            raise ValueError(f"{meter_id}: duration {e['ticks']} not notatable")
        value, dots, tuplet = table[e["ticks"]]
        kind = "rest" if e["rest"] else ("continuation" if prev_tied else "note")
        syl = syllable_at(meter_id, t)
        display = {"note": syl, "rest": f"({syl})", "continuation": f"[{syl}]"}[kind]
        res.append({"startTick": t, "ticks": e["ticks"], "kind": kind, "tieToNext": e["tieToNext"],
                    "syllable": syl, "syllableDisplay": display,
                    "notation": {"value": value, "dots": dots, "tuplet": tuplet}})
        prev_tied = e["tieToNext"]
        t += e["ticks"]
    return res, t

def strength(meter_id, tick):
    """3 = macrobeat, 2 = microbeat, 1 = division / third."""
    starts, length = macro_starts(meter_id)
    tick %= length
    if any(tick == s for s, _ in starts):
        return 3
    return 2 if tick % TPM == 0 else 1

def is_syncopated(meter_id, e):
    """Onset on a weaker grid point than a grid point it sustains through."""
    s0 = strength(meter_id, e["startTick"])
    return any(strength(meter_id, t) > s0
               for t in range(e["startTick"] + 1, e["startTick"] + e["ticks"])
               if t % (TPM // 2) == 0)

def difficulty(events, content, meter_id):
    onsets = sum(1 for e in events if e["kind"] == "note")
    off_micro = sum(1 for e in events if e["kind"] == "note" and e["startTick"] % TPM != 0)
    synco = sum(1 for e in events if e["kind"] == "note" and is_syncopated(meter_id, e))
    score = 0.4 * onsets + 0.5 * off_micro + 1.5 * synco
    score += {"macro_micro": 0, "division": 1, "elongation": 1.5, "rest": 1.5, "tie": 2, "upbeat": 2}[content]
    return "easy" if score < 2.5 else ("moderate" if score < 4.5 else "difficult"), round(score, 2)

def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out, seen = [], set()
    for row in PATTERNS:
        pid, meter, content, body = row[:4]
        pickup = row[4] if len(row) > 4 else None
        assert pid not in seen, pid; seen.add(pid)
        _, measure_len = macro_starts(meter)
        events = []
        pickup_ticks = 0
        if pickup:
            pe = parse(pickup)
            pickup_ticks = sum(e["ticks"] for e in pe)
            ev, _ = build_events(meter, pe, -pickup_ticks)
            for e in ev:
                e["startTick"] = e["startTick"]  # negative = before the barline
                e["isPickup"] = True
            events += ev
        be = parse(body)
        ev, end = build_events(meter, be, 0)
        if end != measure_len:
            sys.exit(f"{pid}: body is {end} ticks, measure is {measure_len}")
        if be[-1]["tieToNext"]:
            sys.exit(f"{pid}: last event cannot be tied forward")
        for e in ev: e["isPickup"] = False
        events += ev
        level, score = difficulty(events, content, meter)
        out.append({
            "id": pid, "meter": meter, "content": content,
            "timeSignature": METERS[meter]["notation"],
            "macrobeats": METERS[meter]["macro"],
            "measureTicks": measure_len, "pickupTicks": pickup_ticks,
            "difficulty": level, "difficultyScore": score,
            "syllables": " ".join(e["syllableDisplay"] for e in events),
            "events": events,
        })
    for size, cells in CELLS.items():
        for tokens, _ in cells:
            if sum(e["ticks"] for e in parse(tokens)) != int(size) * TPM:
                sys.exit(f"cell {tokens} != {size} microbeats")
    doc = {"version": 1, "ticksPerMicrobeat": TPM,
           "meters": METERS, "patterns": out}
    with open(os.path.join(root, "data", "patterns.json"), "w") as f:
        json.dump(doc, f, indent=1, ensure_ascii=False)
    cells_doc = {"version": 1, "ticksPerMicrobeat": TPM,
                 "cells": {k: [{"tokens": t, "minContent": c} for t, c in v] for k, v in CELLS.items()}}
    with open(os.path.join(root, "data", "cells.json"), "w") as f:
        json.dump(cells_doc, f, indent=1, ensure_ascii=False)
    for p in out:
        print(f"{p['id']:10} {p['timeSignature']:4} {p['difficulty']:9} {p['syllables']}")
    print(f"\nOK: {len(out)} patterns")

if __name__ == "__main__":
    main()
