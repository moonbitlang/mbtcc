#include "test.h"

// 测试不同整数类型的运算和转换
int main() {
    char c = 100;
    short s = 2000;
    int i = 50000;
    long l = 1000000;
    unsigned int ui = 4000000000;
    
    // 类型转换和混合运算
    int c_to_i = c + 10;
    int s_to_i = s * 2;
    long i_to_l = i + l;
    unsigned int l_to_ui = ui + l;
    
    printf("Type values:\n");
    printf("char value: %d\n", c);
    printf("short value: %d\n", s);
    printf("int value: %d\n", i);
    printf("long value: %ld\n", l);
    printf("unsigned int value: %u\n", ui);
    
    printf("\nType conversions:\n");
    printf("char + int: %d\n", c_to_i);
    printf("short * int: %d\n", s_to_i);
    printf("int + long: %ld\n", i_to_l);
    printf("unsigned + long: %u\n", l_to_ui);
    
    return 0;
}