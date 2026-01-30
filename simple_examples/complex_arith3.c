#include "test.h"

// 测试复杂的类型转换和精度处理
double precise_division(long num, int denom) {
    return (double)num / denom;
}

float complex_conversion(int x, long y, float z) {
    double temp = (double)x * y;
    float result = (float)(temp / z);
    return result;
}

int main() {
    long large_num = 1234567890L;
    int small_num = 123;
    float float_num = 456.789f;
    double double_num = 789.012;
    
    printf("Original values:\n");
    printf("large_num = %ld\n", large_num);
    printf("small_num = %d\n", small_num);
    printf("float_num = %.3f\n", float_num);
    printf("double_num = %.3f\n", double_num);
    
    // Complex conversions
    double result1 = precise_division(large_num, small_num);
    printf("Precise division: %.6f\n", result1);
    
    float result2 = complex_conversion(small_num, large_num, float_num);
    printf("Complex conversion: %.6f\n", result2);
    
    // Mixed precision arithmetic
    double result3 = (double_num * float_num) / (double)small_num;
    printf("Mixed precision: %.6f\n", result3);
    
    // Integer to float precision loss test
    int big_int = 123456789;
    float float_conv = (float)big_int;
    int back_to_int = (int)float_conv;
    printf("Precision loss test: %d -> %.2f -> %d\n",
           big_int, float_conv, back_to_int);
    
    return 0;
}
