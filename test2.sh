#!/bin/bash

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Directory containing test cases
CTEST_DIR="ctest2"
# Root directory for runtime and other sources
ROOT_DIR="."
# Temporary directory for generated files
TMP_DIR="tmp"

# Array to store failed tests
declare -a failed_tests

# Test categories and their files
basic_tests=(
    "basic_int_arith1.c"
    "basic_int_arith2.c"
    "basic_int_arith3.c"
    "basic_int_arith4.c"
    "basic_int_arith5.c"
    "basic_float_arith1.c"
    "basic_float_arith2.c"
    "basic_float_arith3.c"
    "basic_float_arith4.c"
    "basic_float_arith5.c"
    "basic_control1.c"
    "basic_control2.c"
    "basic_control3.c"
    "basic_control4.c"
    "basic_control5.c"
)

type_tests=(
    "basic_type1.c"
    "basic_type2.c"
    "basic_type3.c"
    "basic_type4.c"
    "basic_type5.c"
)

function_tests=(
    "basic_function1.c"
    "basic_function2.c"
    "basic_function3.c"
    "basic_function4.c"
    "basic_function5.c"
)

complex_tests=(
    "complex_arith1.c"
    "complex_arith2.c"
    "complex_arith3.c"
    "complex_arith4.c"
    "complex_arith5.c"
    "complex_control1.c"
    "complex_control2.c"
    "complex_control3.c"
    "complex_control4.c"
    "complex_control5.c"
    "complex_type1.c"
    "complex_type2.c"
    "complex_type3.c"
    "complex_type4.c"
    "complex_type5.c"
    "complex_function1.c"
    "complex_function2.c"
    "complex_function3.c"
    "complex_function4.c"
    "complex_function5.c"
)

dsa_tests=(
    "dsa_linked_list.c"
    "dsa_stack.c"
    "dsa_queue.c"
    "dsa_binary_tree.c"
    "dsa_binary_search_tree.c"
    "dsa_heap.c"
    "dsa_hash_table.c"
    "dsa_graph.c"
    "dsa_disjoint_set.c"
    "dsa_trie.c"
    "dsa_bubble_sort.c"
    "dsa_selection_sort.c"
    "dsa_insertion_sort.c"
    "dsa_quick_sort.c"
    "dsa_merge_sort.c"
    "dsa_heap_sort.c"
    "dsa_linear_search.c"
    "dsa_binary_search.c"
    "dsa_dfs.c"
    "dsa_bfs.c"
    "dsa_dp_fibonacci.c"
    "dsa_dp_lcs.c"
    "dsa_dp_knapsack.c"
    "dsa_dp_lis.c"
    "dsa_dp_edit_distance.c"
    "dsa_graph_dijkstra.c"
    "dsa_graph_floyd_warshall.c"
    "dsa_graph_kruskal.c"
    "dsa_graph_prim.c"
    "dsa_graph_topological_sort.c"
)

# Clean up and create the temporary directory
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# Check if required commands are available
for cmd in moon clang gcc; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}Error: '$cmd' command not found. Please ensure it is installed and in your PATH.${NC}"
        exit 1
    fi
done

# Function to run a single test
run_test() {
    local test_name=$1
    local category=$2
    local c_file="$CTEST_DIR/$test_name"
    local base_name=$(basename "$c_file" .c)
    
    echo "-------------------------------------------"
    echo -e "${YELLOW}Testing $category: $test_name${NC}"
    
    # Compile and run with GCC
    if ! gcc "$c_file" -lm -o "$TMP_DIR/$base_name.gcc.out" 2>/dev/null; then
        echo -e "${RED}FAILED: GCC compilation failed${NC}"
        failed_tests+=("$category/$test_name (GCC compilation)")
        return
    fi
    
    # Get expected output
    expected_output=$(./"$TMP_DIR/$base_name.gcc.out")
    echo "Expected output (from GCC): $expected_output"
    
    # Compile with mbtcc and clang
    if ! moon run main --warn-list -1-2-3-6-28 -- -file "$c_file" > "$TMP_DIR/$base_name.ll" 2>/dev/null; then
        echo -e "${RED}FAILED: mbtcc compilation failed${NC}"
        failed_tests+=("$category/$test_name (mbtcc compilation)")
        return
    fi
    
    if ! clang -w "$TMP_DIR/$base_name.ll" -lm -o "$TMP_DIR/$base_name.mbtcc.out" 2>/dev/null; then
        echo -e "${RED}FAILED: LLVM compilation failed${NC}"
        failed_tests+=("$category/$test_name (LLVM compilation)")
        return
    fi
    
    # Run and compare outputs
    actual_output=$(./"$TMP_DIR/$base_name.mbtcc.out")
    echo "Actual output (from mbtcc):   $actual_output"
    
    if [ "$expected_output" = "$actual_output" ]; then
        echo -e "${GREEN}PASSED: Outputs match${NC}"
    else
        echo -e "${RED}FAILED: Output mismatch${NC}"
        echo "Expected: '$expected_output'"
        echo "Got:      '$actual_output'"
        failed_tests+=("$category/$test_name (output mismatch)")
    fi
}

# Run tests by category
echo "Running basic tests..."
for test in "${basic_tests[@]}"; do
    run_test "$test" "Basic"
done

echo "Running type tests..."
for test in "${type_tests[@]}"; do
    run_test "$test" "Type"
done

echo "Running function tests..."
for test in "${function_tests[@]}"; do
    run_test "$test" "Function"
done

echo "Running complex tests..."
for test in "${complex_tests[@]}"; do
    run_test "$test" "Complex"
done

echo "Running data structure and algorithm tests..."
for test in "${dsa_tests[@]}"; do
    run_test "$test" "DSA"
done

# Print summary
echo "-------------------------------------------"
echo "Test Summary:"
echo "-------------------------------------------"
total_tests=$((${#basic_tests[@]} + ${#type_tests[@]} + ${#function_tests[@]} + ${#complex_tests[@]} + ${#dsa_tests[@]}))
failed_count=${#failed_tests[@]}
passed_count=$((total_tests - failed_count))

echo -e "${GREEN}Passed: $passed_count${NC}"
echo -e "${RED}Failed: $failed_count${NC}"

if [ $failed_count -gt 0 ]; then
    echo -e "\n${RED}Failed tests:${NC}"
    for test in "${failed_tests[@]}"; do
        echo "- $test"
    done
    exit 1
else
    echo -e "\n${GREEN}All tests passed successfully!${NC}"
    exit 0
fi
