#include "test.h"

// 测试基本的浮点数四则运算
int main() {
    float a = 10.5f;
    float b = 3.2f;
    float sum = a + b;
    float diff = a - b;
    float prod = a * b;
    float quot = a / b;
    
    printf("Values: a = %.2f, b = %.2f\n", a, b);
    printf("Addition: %.2f\n", sum);
    printf("Subtraction: %.2f\n", diff);
    printf("Multiplication: %.2f\n", prod);
    printf("Division: %.2f\n", quot);
    
    return 0;
}
