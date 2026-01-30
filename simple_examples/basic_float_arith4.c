#include "test.h"

// 测试浮点数的数学函数
int main() {
    float x = 16.0f;
    double y = 25.0;
    
    float sqrt_x = sqrtf(x);
    double sqrt_y = sqrt(y);
    
    printf("Square root tests:\n");
    printf("sqrt(%.1f) = %.4f\n", x, sqrt_x);
    printf("sqrt(%.1f) = %.4f\n", y, sqrt_y);
    
    // Mixed float and double operations
    float f1 = 10.5f;
    double d1 = 20.7;
    double result = f1 + d1;
    
    printf("\nMixed precision:\n");
    printf("float(%.2f) + double(%.2f) = %.2f\n", f1, d1, result);
    
    return 0;
}
