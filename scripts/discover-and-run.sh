#!/usr/bin/env bash
set -e

# 1) Locate repo root and cd into the lnd submodule
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/../lnd"

# 2) Discover all fuzz targets
FUZZ_FUNCS=$(grep -RhoP '^func\s+(Fuzz\w+)\(.*\*testing\.F\)' . | sort -u)

# 3) Run each for 1 minute using all cores
for FN in $FUZZ_FUNCS; do
  echo "=== Running $FN ==="
  go test ./... \
    -fuzz="$FN" \
    -fuzztime=1m \
    -parallel=$(nproc) \
    -fuzzdir="../corpora/$FN" \
  || echo "[!] $FN exited non-zero"
done
