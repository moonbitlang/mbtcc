#include "test.h"

// 测试复杂的整数和浮点数混合运算
double calculate_expression(int a, float b, double c) {
    double result = (a * b + c) / (b - a) + sqrt(c);
    return result;
}

float complex_operation(int x, int y, float z) {
    float result = (x + y) * z / (x - y);
    result = result * result + sqrtf(z);
    return result;
}

int main() {
    int a = 5;
    float b = 10.5f;
    double c = 15.7;
    
    printf("Values: a = %d, b = %.2f, c = %.2f\n", a, b, c);
    
    double result1 = calculate_expression(a, b, c);
    printf("Complex expression 1: %.4f\n", result1);
    
    int x = 8;
    int y = 3;
    float z = 12.3f;
    
    float result2 = complex_operation(x, y, z);
    printf("Complex expression 2: %.4f\n", result2);
    
    // Mixed precision calculations
    double mixed = (a * b + c) / (x * y - z) + sqrt(result2);
    printf("Mixed precision result: %.4f\n", mixed);
    
    return 0;
}
