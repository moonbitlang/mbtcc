#include "test.h"

// 测试基本的整数四则运算和取模
int main() {
    int a = 10;
    int b = 3;
    int sum = a + b;
    int diff = a - b;
    int prod = a * b;
    int quot = a / b;
    int rem = a % b;
    
    printf("Values: a = %d, b = %d\n", a, b);
    printf("Addition: %d\n", sum);
    printf("Subtraction: %d\n", diff);
    printf("Multiplication: %d\n", prod);
    printf("Division: %d\n", quot);
    printf("Remainder: %d\n", rem);
    
    return 0;
}