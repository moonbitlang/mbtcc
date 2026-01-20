#include "test.h"

// 测试浮点数的精度和边界情况
int main() {
    float small = 0.000001f;
    float large = 1000000.0f;
    float product = small * large;
    
    printf("Precision tests:\n");
    printf("Small number: %e\n", small);
    printf("Large number: %e\n", large);
    printf("Product: %e\n", product);
    
    // Integer to float precision
    int big_int = 123456789;
    float float_conv = (float)big_int;
    int back_to_int = (int)float_conv;
    
    printf("\nConversion precision:\n");
    printf("Original int: %d\n", big_int);
    printf("As float: %.2f\n", float_conv);
    printf("Back to int: %d\n", back_to_int);
    
    return 0;
}
