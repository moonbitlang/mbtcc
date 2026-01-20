#include "test.h"

// 测试浮点数的赋值运算和类型转换
int main() {
    float x = 5.5f;
    printf("Initial value: x = %.2f\n", x);
    
    x += 3.3f;
    printf("Add-assign: %.2f\n", x);
    
    x -= 2.1f;
    printf("Subtract-assign: %.2f\n", x);
    
    x *= 2.0f;
    printf("Multiply-assign: %.2f\n", x);
    
    x /= 4.0f;
    printf("Divide-assign: %.2f\n", x);
    
    // Type conversion tests
    int i = (int)x;
    float f = (float)i;
    double d = (double)f;
    
    printf("Float to int: %d\n", i);
    printf("Int to float: %.2f\n", f);
    printf("Float to double: %.2f\n", d);
    
    return 0;
}
