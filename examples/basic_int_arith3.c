#include "test.h"

// 测试整数的位运算
int main() {
    int a = 12;  // binary: 1100
    int b = 5;   // binary: 0101
    
    int and_result = a & b;
    int or_result = a | b;
    int xor_result = a ^ b;
    int not_result = ~a;
    int left_shift = a << 2;
    int right_shift = a >> 1;
    
    printf("Values: a = %d, b = %d\n", a, b);
    printf("Bitwise AND: %d\n", and_result);
    printf("Bitwise OR: %d\n", or_result);
    printf("Bitwise XOR: %d\n", xor_result);
    printf("Bitwise NOT: %d\n", not_result);
    printf("Left shift: %d\n", left_shift);
    printf("Right shift: %d\n", right_shift);
    
    return 0;
}