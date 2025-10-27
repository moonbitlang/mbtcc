#include "test.h"

// 测试递归函数和互相调用的函数
int factorial(int n);
int fibonacci(int n);
int ackermann(int m, int n);
int gcd(int a, int b);
int lcm(int a, int b);

// Factorial calculation using recursion
int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

// Fibonacci calculation using recursion
int fibonacci(int n) {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// Ackermann function - a recursive function that grows very quickly
int ackermann(int m, int n) {
    if (m == 0) return n + 1;
    if (n == 0) return ackermann(m - 1, 1);
    return ackermann(m - 1, ackermann(m, n - 1));
}

// Greatest Common Divisor using recursion
int gcd(int a, int b) {
    if (b == 0) return a;
    return gcd(b, a % b);
}

// Least Common Multiple using GCD
int lcm(int a, int b) {
    return (a * b) / gcd(a, b);
}

// Function to test number properties using multiple recursive functions
void analyze_number(int n) {
    printf("Analysis of number %d:\n", n);
    printf("Factorial: %d\n", factorial(n));
    printf("Fibonacci: %d\n", fibonacci(n));
    
    if (n <= 2) {
        printf("Ackermann(2,%d): %d\n", n, ackermann(2, n));
    }
    
    int test_numbers[] = {12, 18, 24, 36};
    printf("GCD with common numbers:\n");
    for (int i = 0; i < 4; i++) {
        printf("GCD(%d,%d) = %d\n", n, test_numbers[i], 
               gcd(n, test_numbers[i]));
    }
    
    printf("LCM with common numbers:\n");
    for (int i = 0; i < 4; i++) {
        printf("LCM(%d,%d) = %d\n", n, test_numbers[i], 
               lcm(n, test_numbers[i]));
    }
}

int main() {
    // Test various numbers
    int test_values[] = {4, 5, 6};
    
    for (int i = 0; i < 3; i++) {
        printf("\n");
        analyze_number(test_values[i]);
    }
    
    return 0;
}
