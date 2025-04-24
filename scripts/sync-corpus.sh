#!/usr/bin/env bash
set -euo pipefail

# 1. Locate script & repo
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$SCRIPT_DIR/.."
FUZZ_DIR="$REPO_ROOT/lnd-fuzz"
PERSIST_DIR="$REPO_ROOT/corpuses"

mkdir -p "$PERSIST_DIR"

echo "▶ Repo root:      $REPO_ROOT"
echo "▶ Looking under:  $FUZZ_DIR for fuzz targets"

# 2. Find all Fuzz* functions in lnd-fuzz
mapfile -t fuzz_targets < <(
  grep -R --include='*.go' 'func Fuzz' "$FUZZ_DIR" \
    | sed -n 's/.*func \(Fuzz[^ (]*\).*/\1/p' \
    | sort -u
)

echo "▶ Discovered fuzz targets: ${fuzz_targets[*]:-<none>}"

for target in "${fuzz_targets[@]}"; do
  echo
  echo "=== Processing target: $target ==="

  # 3. Find the package directory for this target
  pkg_file=$(grep -R --include='*.go' -l "func $target" "$FUZZ_DIR" | head -n1)
  pkg_dir=$(dirname "$pkg_file")
  echo "  • Package dir: $pkg_dir"

  # 4. Paths for preload & persistence
  dst_dir="$pkg_dir/testdata/fuzz/$target"   # where go test -fuzz writes seeds
  src_dir="$PERSIST_DIR/$target"              # our long‑term store

  echo "  • Preloading seeds from: ${src_dir} → ${dst_dir}"
  rm -rf "$dst_dir"
  mkdir -p "$dst_dir"
  if [ -d "$src_dir" ] && [ "$(ls -A "$src_dir")" ]; then
    cp -a "$src_dir/"* "$dst_dir/"
  else
    echo "    (no previous seeds found; starting fresh)"
  fi

  # 5. Run the fuzzer (adjust -fuzztime as desired)
  (
    cd "$pkg_dir"
    echo "  • Running: go test -timeout 60m -run=^$ -fuzz=$target -fuzztime=30s"
    go test -timeout 60m -run=^$ -fuzz="$target" -fuzztime=30s
  )

  # 6. Persist any new seeds back into PERSIST_DIR
  echo "  • Saving new seeds from ${dst_dir} → ${src_dir}"
  mkdir -p "$src_dir"
  cp -a "$dst_dir/"* "$src_dir/" || true
done

echo
echo "✓ Done. Corpuses stored under: $PERSIST_DIR"
