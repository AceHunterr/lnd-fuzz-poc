#!/usr/bin/env bash
set -e


LOG_DIR="../logs"
mkdir -p $LOG_DIR
LOG_FILE="$LOG_DIR/coverage-run-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting coverage analysis at $(date)"
echo "Logging output to $LOG_FILE"

# Defining location of the LND directory
cd "$(dirname "$0")"/../lnd


COVERAGE_DIR="../coverage-reports"
mkdir -p $COVERAGE_DIR
DATE_STAMP=$(date +%Y%m%d-%H%M%S)

if [ ! -d "../lnd-fuzz" ]; then
  echo "Cloning public fuzzing corpus..."
  git clone https://github.com/lightninglabs/lnd-fuzz ../lnd-fuzz
fi

# Discover all fuzz targets for code coverage
echo "Discovering fuzz targets..."
FUZZ_FUNCS=$(grep -rhoP '^func\s+(Fuzz\w+)' --include="*.go" . | sed 's/^func //' | sort -u)
echo "Found fuzz targets: $FUZZ_FUNCS"

# For each fuzz target, find its package and generate coverage
for FUNC in $FUZZ_FUNCS; do
  FILE=$(grep -r --include="*.go" -l "func $FUNC" . | head -1)
  
  if [ -z "$FILE" ]; then
    echo "Could not find file containing $FUNC, skipping..."
    continue
  fi
  

  PKG_PATH=$(dirname "$FILE" | sed 's|^./||')
  PKG_NAME=$(grep -m 1 "package " "$FILE" | sed 's/package //')
  
  echo "Processing $FUNC found in $FILE (package: $PKG_NAME, path: $PKG_PATH)"
  
  CORPUS_DIR="../lnd-fuzz/corpora/$FUNC"
  mkdir -p "$CORPUS_DIR"
  
  if [ ! "$(ls -A $CORPUS_DIR 2>/dev/null)" ]; then
    echo "Creating initial corpus for $FUNC..."
    echo "sample_input" > "$CORPUS_DIR/sample"
  fi
  
  # Run coverage using the fuzz test function but with run flag instead of fuzz
  echo "Running coverage analysis..."
  
  COVERAGE_FILE="$COVERAGE_DIR/${FUNC}_${DATE_STAMP}.out"
  
  go test "./$PKG_PATH" -run="^${FUNC}$" -coverprofile="$COVERAGE_FILE" \
    -covermode=atomic -coverpkg=./... || true
  
  if [ -s "$COVERAGE_FILE" ]; then
    go tool cover -html="$COVERAGE_FILE" -o "$COVERAGE_DIR/${FUNC}_${DATE_STAMP}.html"
    echo "✅ Coverage report generated for $FUNC at $COVERAGE_DIR/${FUNC}_${DATE_STAMP}.html"
  else
    echo "⚠️ No coverage data generated for $FUNC"
    
    TEST_FILES=$(find "$PKG_PATH" -name "*_test.go" 2>/dev/null || echo "")
    if [ -n "$TEST_FILES" ]; then
      echo "Test files found in package. Available test functions:"
      grep -h "^func Test" $TEST_FILES 2>/dev/null || echo "No test functions found"
    fi
  fi
  
  echo "------------------------------------------------------"
done

echo "Coverage analysis complete at $(date)"
echo "Reports available in $COVERAGE_DIR"

NUM_REPORTS=$(find "$COVERAGE_DIR" -name "*.html" -newer "$LOG_FILE" | wc -l)
echo "Total successful coverage reports: $NUM_REPORTS"

echo "Logging complete. Full log available at $LOG_FILE"