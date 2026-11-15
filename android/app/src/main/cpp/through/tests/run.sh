#!/bin/bash
# Builds and runs the audio-through host test on the Mac (no Android, no device): the resampler's quality, the adaptive
# buffer against modelled FM-1 packet streams, the dropout detector, and the FM-1's packet pacing today vs proposed.
set -euo pipefail
cd "$(dirname "$0")"
OUT="${TMPDIR:-/tmp}/through_test"
clang++ -std=c++17 -O2 -Wall -Wextra -fsanitize=address,undefined -o "$OUT" through_test.cpp
"$OUT"
