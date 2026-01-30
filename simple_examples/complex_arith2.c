#include "test.h"

// 测试复杂的位运算组合
unsigned int rotate_left(unsigned int value, int shift) {
    return (value << shift) | (value >> (32 - shift));
}

unsigned int rotate_right(unsigned int value, int shift) {
    return (value >> shift) | (value << (32 - shift));
}

unsigned int bit_manipulation(unsigned int a, unsigned int b) {
    unsigned int result = (a & 0xF0F0) | (b & 0x0F0F);
    result = rotate_left(result, 4);
    result ^= (a ^ b);
    result = rotate_right(result, 8);
    return result;
}

int main() {
    unsigned int x = 0xABCD1234;
    unsigned int y = 0x12345678;
    
    printf("Original values:\n");
    printf("x = 0x%08X\n", x);
    printf("y = 0x%08X\n", y);
    
    unsigned int rotated_left = rotate_left(x, 12);
    printf("Rotated left by 12: 0x%08X\n", rotated_left);
    
    unsigned int rotated_right = rotate_right(y, 8);
    printf("Rotated right by 8: 0x%08X\n", rotated_right);
    
    unsigned int manipulated = bit_manipulation(x, y);
    printf("Bit manipulated result: 0x%08X\n", manipulated);
    
    // Complex bit operations
    unsigned int complex_result = ((x & y) << 16) | ((x | y) >> 16);
    printf("Complex bit operation: 0x%08X\n", complex_result);
    
    return 0;
}
