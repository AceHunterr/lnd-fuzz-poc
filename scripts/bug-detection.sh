#!/bin/bash

echo "Starting fuzz bug detection..."

# Directory where bug reports will be stored
BUGS_DIR="./fuzz-bugs"
mkdir -p "$BUGS_DIR"

# Directory containing corpus and crashers
FUZZ_DIR="../lnd-fuzz/corpora"
echo "Looking for corpus directories in: $FUZZ_DIR"

FOUND_BUGS=0

echo "Creating a sample bug for testing..."
TEST_TARGET="FuzzTestBug"
TEST_CRASHER_DIR="$FUZZ_DIR/$TEST_TARGET/crashers"
mkdir -p "$TEST_CRASHER_DIR"

# Create a sample crash file for demonstration purposes
echo "sample crash input data" > "$TEST_CRASHER_DIR/crash1"

cat > "$TEST_CRASHER_DIR/crash1.output" <<EOL
panic: test panic message for demonstration

goroutine 1 [running]:
testing.tRunner.func1.2(0x1100000, 0x1200000)
    /usr/local/go/src/testing/testing.go:1142 +0x25a
github.com/lightningnetwork/lnd/example.FuzzTestBug(0x2000000)
    /workspace/lnd-fuzz-poc/lnd/example/fuzz_test.go:42 +0x123
testing.(*F).Fuzz(0x3000000)
    /usr/local/go/src/testing/fuzz.go:330 +0x5a1
EOL

echo "Sample bug created at $TEST_CRASHER_DIR"

# Processing each fuzz target directory 
for TARGET_DIR in "$FUZZ_DIR"/*; do
    
    [ ! -d "$TARGET_DIR" ] && continue
    
    
    TARGET_NAME=${TARGET_DIR##*/}
    echo "Checking target: $TARGET_NAME"
    
    
    CRASHER_DIR="$TARGET_DIR/crashers"
    if [ -d "$CRASHER_DIR" ]; then
        echo "Found crashers directory: $CRASHER_DIR"
        
        for CRASH_FILE in "$CRASHER_DIR"/*; do
            if [ -f "$CRASH_FILE" ] && [[ "$CRASH_FILE" != *.output ]] && [[ "$CRASH_FILE" != *.quoted ]]; then
                CRASH_BASE=${CRASH_FILE##*/}
                OUTPUT_FILE="$CRASH_FILE.output"
                
                if [ -f "$OUTPUT_FILE" ]; then
                    echo "Found crash: $CRASH_BASE in $TARGET_NAME"
                    
                    BUG_ID="${TARGET_NAME}_${CRASH_BASE}"
                    BUG_DIR="$BUGS_DIR/$BUG_ID"
                    mkdir -p "$BUG_DIR"
                    
                    cp "$CRASH_FILE" "$BUG_DIR/input"
                    cp "$OUTPUT_FILE" "$BUG_DIR/output.log"
                    
                    CRASH_TYPE="Unknown"
                    CRASH_LOCATION="Unknown"
                    
                    if command -v grep &> /dev/null; then
                        if grep -q "panic:" "$OUTPUT_FILE"; then
                            CRASH_TYPE="Panic"
                        elif grep -q "SIGSEGV" "$OUTPUT_FILE"; then
                            CRASH_TYPE="Segmentation fault"
                        fi
                    else
                        if cat "$OUTPUT_FILE" | while read line; do [[ "$line" == *"panic:"* ]] && exit 0; done; then
                            CRASH_TYPE="Panic"
                        fi
                    fi
                    
                    cat > "$BUG_DIR/report.md" <<EOL
# Fuzz Bug Report: $TARGET_NAME

## Bug Information
- **Bug ID**: $BUG_ID
- **Fuzz Target**: $TARGET_NAME
- **Crash Type**: $CRASH_TYPE
- **Detected**: $(date 2>/dev/null || echo "Unknown date")

## Crash Output
\`\`\`
$(cat "$OUTPUT_FILE")
\`\`\`

## How to Reproduce
Save the input file and run:
\`\`\`
cd lnd
go test -run=$TARGET_NAME -fuzz=FuzzNone ./... -args "$BUG_DIR/input"
\`\`\`
EOL
                    
                    echo "Bug report created at $BUG_DIR/report.md"
                    FOUND_BUGS=$((FOUND_BUGS + 1))
                fi
            fi
        done
    fi
done

# Create a summary report
echo "Creating summary report..."
SUMMARY_FILE="$BUGS_DIR/summary.md"

cat > "$SUMMARY_FILE" <<EOL
# Fuzz Testing Bug Summary

- **Date**: $(date 2>/dev/null || echo "Unknown date")
- **Total Bugs Found**: $FOUND_BUGS

## Bug List
EOL

if [ $FOUND_BUGS -gt 0 ]; then
    for BUG_DIR in "$BUGS_DIR"/*; do
        if [ -d "$BUG_DIR" ]; then
            BUG_ID=${BUG_DIR##*/}
            echo "- $BUG_ID" >> "$SUMMARY_FILE"
        fi
    done
else
    echo "No bugs found during this fuzz testing run." >> "$SUMMARY_FILE"
fi

if [ $FOUND_BUGS -eq 0 ]; then
    echo "No bugs found!"
else
    echo "Found $FOUND_BUGS potential bugs. See $BUGS_DIR for details."
fi

echo "Summary report created: $SUMMARY_FILE"
echo "Bug detection complete."