#include "test.h"

// 斐波那契数列的不同实现方法
// 递归实现
int fib_recursive(int n) {
    if (n <= 1) return n;
    return fib_recursive(n - 1) + fib_recursive(n - 2);
}

// 动态规划 - 自底向上
int fib_dp_bottom_up(int n) {
    if (n <= 1) return n;
    
    int dp[n + 1];
    dp[0] = 0;
    dp[1] = 1;
    
    printf("Building DP table:\n");
    printf("dp[0] = 0\n");
    printf("dp[1] = 1\n");
    
    for (int i = 2; i <= n; i++) {
        dp[i] = dp[i - 1] + dp[i - 2];
        printf("dp[%d] = dp[%d] + dp[%d] = %d\n",
               i, i-1, i-2, dp[i]);
    }
    
    return dp[n];
}

// 动态规划 - 空间优化
int fib_dp_optimized(int n) {
    if (n <= 1) return n;
    
    int prev2 = 0, prev1 = 1, current;
    printf("Starting with prev2 = 0, prev1 = 1\n");
    
    for (int i = 2; i <= n; i++) {
        current = prev1 + prev2;
        printf("Step %d: current = %d + %d = %d\n",
               i, prev1, prev2, current);
        prev2 = prev1;
        prev1 = current;
    }
    
    return current;
}

// 测试函数
void test_fibonacci(int n) {
    printf("\nTesting Fibonacci calculations for n = %d:\n", n);
    
    // 递归方法
    printf("\nRecursive method:\n");
    int result1 = fib_recursive(n);
    printf("Result: %d\n", result1);
    
    // 动态规划 - 自底向上
    printf("\nDynamic Programming (Bottom-up):\n");
    int result2 = fib_dp_bottom_up(n);
    printf("Result: %d\n", result2);
    
    // 动态规划 - 空间优化
    printf("\nDynamic Programming (Space Optimized):\n");
    int result3 = fib_dp_optimized(n);
    printf("Result: %d\n", result3);
}

// 性能比较测试
void performance_test() {
    printf("\nPerformance comparison for different values of n:\n");
    int test_values[] = {5, 10, 15, 20};
    int num_tests = sizeof(test_values) / sizeof(test_values[0]);
    
    for (int i = 0; i < num_tests; i++) {
        int n = test_values[i];
        printf("\nTesting n = %d:\n", n);
        
        // 为了简单起见，这里不测量具体时间，只显示结果
        printf("Recursive result: %d\n", fib_recursive(n));
        printf("DP Bottom-up result: %d\n", fib_dp_bottom_up(n));
        printf("DP Optimized result: %d\n", fib_dp_optimized(n));
    }
}

// 边界情况测试
void test_edge_cases() {
    printf("\nTesting edge cases:\n");
    
    printf("\nn = 0:\n");
    test_fibonacci(0);
    
    printf("\nn = 1:\n");
    test_fibonacci(1);
    
    printf("\nn = 2:\n");
    test_fibonacci(2);
}

int main() {
    // 基本测试
    test_fibonacci(7);
    
    // 性能比较
    performance_test();
    
    // 边界情况
    test_edge_cases();
    
    return 0;
}
