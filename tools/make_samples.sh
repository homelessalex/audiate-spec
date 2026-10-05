#!/bin/zsh
# Generates Resources/Samples/*.caf (docs/05-architecture.md §6) with macOS `say` + `afconvert`.
# All samples: mono, 16-bit linear PCM, 44.1 kHz, perceptual onset at sample 0, <= 250 ms.
# Run: tools/make_samples.sh [voice]   (default voice: Samantha)
set -euo pipefail

ROOT="${0:A:h:h}"
OUT="$ROOT/Resources/Samples"
VOICE="${1:-Samantha}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

# [uncertain] TTS spellings; tune by ear. Neutral is "bum" because "bah" collides with syllable "ba".
typeset -A SPELLING=(
  du doo  de day  ta tah  da dah  di dee  be bay  ba bah  bi bee  neutral bum
)

to_caf() { afconvert -f caff -d LEI16 "$1" "$2"; }

for name spelling in ${(kv)SPELLING}; do
  say -v "$VOICE" -o "$TMP/$name.aiff" "$spelling"
  afconvert -f WAVE -d LEI16@44100 -c 1 "$TMP/$name.aiff" "$TMP/$name.raw.wav"
  python3 "$ROOT/tools/process_sample.py" trim "$TMP/$name.raw.wav" "$TMP/$name.wav"
  to_caf "$TMP/$name.wav" "$OUT/$name.caf"
done

for kind in hi lo; do
  python3 "$ROOT/tools/process_sample.py" click "$TMP/click_$kind.wav" "$kind"
  to_caf "$TMP/click_$kind.wav" "$OUT/click_$kind.caf"
done
python3 "$ROOT/tools/process_sample.py" click "$TMP/tap.wav" tap
to_caf "$TMP/tap.wav" "$OUT/tap.caf"

ls -1 "$OUT"
