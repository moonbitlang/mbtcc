#include "test.h"

// 测试浮点数的比较运算
int main() {
    float a = 3.14f;
    float b = 3.14159f;
    float c = 3.14f;
    
    printf("Values: a = %.5f, b = %.5f, c = %.5f\n", a, b, c);
    
    printf("Equal test (a == c): %d\n", a == c);
    printf("Not equal test (a != b): %d\n", a != b);
    printf("Greater than (b > a): %d\n", b > a);
    printf("Less than (a < b): %d\n", a < b);
    printf("Greater or equal (a >= c): %d\n", a >= c);
    printf("Less or equal (a <= b): %d\n", a <= b);
    
    // Small difference comparison
    float small_diff = b - a;
    printf("Small difference: %.5f\n", small_diff);
    
    return 0;
}
