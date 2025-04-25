# #!/usr/bin/env bash
# set -e

# # How many seconds to fuzz each target (default 10)
# FUZZ_TIME=${1:-10}

# # Compute absolute paths
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# REPO_ROOT="${SCRIPT_DIR}/.."
# LND_ROOT="${REPO_ROOT}/lnd"

# # Move into the LND module (where go.mod lives)
# cd "$LND_ROOT"

# # 1) Find every Go file that defines a fuzz target
# #    We look for func FuzzXXX(*testing.F)
# mapfile -t FUZZ_FILES < <(
#   grep -R --include='*.go' -Pl '^func\s+Fuzz\w+\(.*\*testing\.F' .
# )

# # 2) For each file, extract the exact target names and run them
# for file in "${FUZZ_FILES[@]}"; do
#   pkg_dir="$(dirname "$file")"

#   # Extract unique fuzz function names from that file
#   mapfile -t FUNCS < <(
#     grep -oP '(?<=^func\s)Fuzz\w+' "$file" | sort -u
#   )

#   for FN in "${FUNCS[@]}"; do
#     echo "=== Fuzzing $FN in $pkg_dir for ${FUZZ_TIME}s ==="
#     (
#       cd "$pkg_dir"
#       # run fuzz on this single package
#       go test . \
#         -fuzz="$FN" \
#         -fuzztime="${FUZZ_TIME}s" \
#         -parallel=$(nproc)
#     )
#   done
# done


#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# LOGGING SETUP
LOG_DIR="${SCRIPT_DIR}/../results"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/discover-and-run-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1


# How many seconds to fuzz each, default 10
FUZZ_TIME=${1:-10}

REPO_ROOT="${SCRIPT_DIR}/.."
LND_ROOT="${REPO_ROOT}/lnd"

# Start in the LND module (so 'go test .' finds go.mod)
cd "$LND_ROOT"

# 1) Find all Go files defining fuzz targets
#    Matches lines like: func FuzzFoo(*testing.F)
mapfile -t FUZZ_FILES < <(
  grep -R --include='*.go' -Pl '^func\s+Fuzz\w+\(.*\*testing\.F' .
)

# 2) Loop over each file
for file in "${FUZZ_FILES[@]}"; do
  pkg_dir="$(dirname "$file")"

  # # --- Skip everything before lnwire/ ---
  # # Only fuzz targets in lnwire (or its subdirs)
  # if [[ "$pkg_dir" != */lnwire* ]]; then
  #   continue
  # fi

  # 3) Extract each unique fuzz function name
  mapfile -t FUNCS < <(
    grep -oP '(?<=^func\s)Fuzz\w+' "$file" | sort -u
  )

  # 4) Fuzz each target *exactly* for FUZZ_TIME seconds
  for FN in "${FUNCS[@]}"; do
    echo "=== Fuzzing $FN in $pkg_dir for ${FUZZ_TIME}s ==="
    (
      cd "$pkg_dir"
      go test . \
        -fuzz="^${FN}$" \
        -fuzztime="${FUZZ_TIME}s" \
        -parallel=$(nproc)
    )
  done
done
