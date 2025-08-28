#!/bin/bash

# 运行 moon check
echo "Running moon check..."
if ! moon check --warn-list -1-2-6-28; then
    echo "Test Failed"
    exit 1
fi

# 运行 moon test
echo "Running moon test..."
if ! moon test --warn-list -1-2-6-28; then
    echo "Test Failed"
    exit 1
fi

# 定义文件数组
files=("ret42.c" "simple_add.c" "simple_addf.c" "simple_unary.c")

# 循环处理每个文件
for filename in "${files[@]}"; do
    echo "Testing file: $filename"
    if ! moon run main --warn-list -1-2-6-28 -- -file "ctest/$filename" --no-print-llvm; then
        echo "Test Failed"
        exit 1
    fi
done

# 所有测试通过
echo "All Test Passed"
