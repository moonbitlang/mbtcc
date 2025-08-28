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
# Temporary directory for generated files
TMP_DIR="tmp"

# --- List of tests that are expected to pass ---
passing_tests=(
  "ret42.c"
  "simple_add.c"
  "simple_addf.c"
  "simple_unary.c"
  "simple_call.c"
  "simple_ptr.c"
  "simple_ptr2.c"
  "simple_if.c"
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

# Check if llc and gcc are available
if ! command -v llc &> /dev/null || ! command -v gcc &> /dev/null
then
    echo -e "${RED}Error: 'llc' or 'gcc' command not found. Please ensure LLVM and GCC are installed and in your PATH.${NC}"
    exit 1
fi

echo "Running comparison tests for selected files..."

# Loop through the curated list of passing tests
for test_name in "${passing_tests[@]}"; do
    c_file="$CTEST_DIR/$test_name"
    base_name=$(basename "$c_file" .c)
    echo "-------------------------------------------"
    echo "Testing $test_name..."

    # --- Step 1: Compile and run with GCC to get the expected result ---
    gcc "$c_file" -o "$TMP_DIR/$base_name.gcc.out"
    
    # Temporarily disable exit-on-error to capture the return code
    set +e
    ./"$TMP_DIR/$base_name.gcc.out"
    expected_ret=$?
    set -e
    
    echo "Expected return code (from GCC): $expected_ret"

    # --- Step 2: Compile with mbtcc, then llc, then link with gcc ---
    moon run main --warn-list -1-2-6-28 -- -file "$c_file" > "$TMP_DIR/$base_name.ll"
    llc -filetype=obj -o "$TMP_DIR/$base_name.o" "$TMP_DIR/$base_name.ll"
    gcc -o "$TMP_DIR/$base_name.mbtcc.out" "$TMP_DIR/$base_name.o"

    # --- Step 3: Run the mbtcc-generated executable and get the actual result ---
    # Temporarily disable exit-on-error to capture the return code
    set +e
    ./"$TMP_DIR/$base_name.mbtcc.out"
    actual_ret=$?
    set -e

    echo "Actual return code (from mbtcc): $actual_ret"

    # --- Step 4: Compare results ---
    if [ "$expected_ret" -eq "$actual_ret" ]; then
        echo -e "${GREEN}PASSED: Return codes match ($expected_ret).${NC}"
    else
        echo -e "${RED}FAILED: Return code mismatch. Expected $expected_ret, but got $actual_ret.${NC}"
        exit 1 # Exit on first failure
    fi
done

echo "-------------------------------------------"
echo -e "${GREEN}All selected tests passed successfully!${NC}"
