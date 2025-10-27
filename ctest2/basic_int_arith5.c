#include "test.h"

// 测试整数的比较运算和逻辑运算
int main() {
    int a = 10;
    int b = 20;
    int c = 10;
    
    // 比较运算
    int equal = a == c;
    int not_equal = a != b;
    int greater = b > a;
    int less = a < b;
    int greater_equal = a >= c;
    int less_equal = a <= b;
    
    // 逻辑运算
    int and_result = (a < b) && (b > c);
    int or_result = (a == b) || (a == c);
    int not_result = !(a == b);
    
    printf("Values: a = %d, b = %d, c = %d\n", a, b, c);
    printf("Equality test: %d\n", equal);
    printf("Inequality test: %d\n", not_equal);
    printf("Greater than: %d\n", greater);
    printf("Less than: %d\n", less);
    printf("Greater or equal: %d\n", greater_equal);
    printf("Less or equal: %d\n", less_equal);
    
    printf("Logical AND: %d\n", and_result);
    printf("Logical OR: %d\n", or_result);
    printf("Logical NOT: %d\n", not_result);
    
    return 0;
}