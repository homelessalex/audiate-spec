#!/bin/zsh
# Generates Resources/Samples/*.caf (docs/05-architecture.md §6): synthesized percussion, no voice.
# All samples: mono, 16-bit linear PCM, 44.1 kHz, attack at sample 0.
# Run: tools/make_samples.sh
set -euo pipefail

ROOT="${0:A:h:h}"
OUT="$ROOT/Resources/Samples"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

python3 "$ROOT/tools/synth_samples.py" "$TMP"
for wav in "$TMP"/*.wav; do
  afconvert -f caff -d LEI16 "$wav" "$OUT/${wav:t:r}.caf"
done
ls -1 "$OUT"
