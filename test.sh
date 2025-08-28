#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Running static analysis..."
moon check --warn-list -1-2-6-28

echo "Running parsing tests..."
moon test --warn-list -1-2-6-28

echo "All preliminary checks passed. Starting main tests..."

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Directory containing test cases
CTEST_DIR="ctest"
# Root directory for runtime and other sources
ROOT_DIR="."
# Temporary directory for generated files
TMP_DIR="tmp"

# --- List of tests that are expected to pass ---
passing_tests=(
  "ret42.c"
  "addi32.c"
  "addf32.c"
  "unary1.c"
  "call.c"
  "ptr1.c"
  "ptr2.c"
  "if.c"
  "if2.c"
  "fib.c"
  "while.c"
  "dowhile.c"
  "for.c"
  "arr1.c"
  "arr2.c"
  "arr3.c"
  "sum_of_arr.c"
  "typedef.c"
  "simple_int.c"
  "bin_int.c"
  "bin_float.c"
)

# Clean up and create the temporary directory
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# Check if moon is available
if ! command -v moon &> /dev/null
then
    echo -e "${RED}Error: 'moon' command not found. Please ensure Moonbit is installed and in your PATH.${NC}"
    exit 1
fi

# Check if clang and gcc are available
if ! command -v clang &> /dev/null || ! command -v gcc &> /dev/null
then
    echo -e "${RED}Error: 'clang' or 'gcc' command not found. Please ensure LLVM and GCC are installed and in your PATH.${NC}"
    exit 1
fi

echo "Running comparison tests for selected files..."

# Loop through the curated list of passing tests
for test_name in "${passing_tests[@]}"; do
    c_file="$CTEST_DIR/$test_name"
    runtime_c="$ROOT_DIR/runtime.c"
    base_name=$(basename "$c_file" .c)
    echo "-------------------------------------------"
    echo "Testing $test_name..."

    # --- Step 1: Compile and run with GCC to get the expected output ---
    gcc "$c_file" "$runtime_c" -o "$TMP_DIR/$base_name.gcc.out"
    expected_output=$(./"$TMP_DIR/$base_name.gcc.out")
    echo "Expected output (from GCC): $expected_output"

    # --- Step 2: Compile with mbtcc, then clang, to produce the mbtcc executable ---
    moon run main --warn-list -1-2-6-28 -- -file "$c_file" > "$TMP_DIR/$base_name.ll"
    clang "$TMP_DIR/$base_name.ll" "$runtime_c" -o "$TMP_DIR/$base_name.mbtcc.out"

    # --- Step 3: Run the mbtcc-generated executable and get the actual output ---
    actual_output=$(./"$TMP_DIR/$base_name.mbtcc.out")
    echo "Actual output (from mbtcc):   $actual_output"

    # --- Step 4: Compare results ---
    if [ "$expected_output" = "$actual_output" ]; then
        echo -e "${GREEN}PASSED: Outputs match.${NC}"
    else
        echo -e "${RED}FAILED: Output mismatch.${NC}"
        echo "Expected: '$expected_output'"
        echo "Got:      '$actual_output'"
        exit 1 # Exit on first failure
    fi
done

echo "-------------------------------------------"
echo -e "${GREEN}All selected tests passed successfully!${NC}"
