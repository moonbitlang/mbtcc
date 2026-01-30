#include "test.h"

// 测试整数的自增自减和赋值运算
int main() {
    int x = 5;
    printf("Initial value: x = %d\n", x);
    
    x++;
    printf("Post-increment: %d\n", x);
    
    ++x;
    printf("Pre-increment: %d\n", x);
    
    x--;
    printf("Post-decrement: %d\n", x);
    
    --x;
    printf("Pre-decrement: %d\n", x);
    
    x += 3;
    printf("Add-assign: %d\n", x);
    
    x -= 2;
    printf("Subtract-assign: %d\n", x);
    
    x *= 4;
    printf("Multiply-assign: %d\n", x);
    
    x /= 2;
    printf("Divide-assign: %d\n", x);
    
    return 0;
}