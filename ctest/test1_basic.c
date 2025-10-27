#include "test.h"

#define MAX_VALUE 100

int main() {
    // 基本算术运算
    int a = 42;
    int b = 8;
    printf("Arithmetic:\n");
    printf("%d + %d = %d\n", a, b, a + b);
    printf("%d - %d = %d\n", a, b, a - b);
    printf("%d * %d = %d\n", a, b, a * b);
    printf("%d / %d = %d\n", a, b, a / b);
    printf("%d %% %d = %d\n", a, b, a % b);
    
    // Relational and logical operations
    printf("\nRelational and logical:\n");
    printf("%d > %d = %d\n", a, b, a > b);
    printf("%d < MAX_VALUE = %d\n", a, a < MAX_VALUE);
    printf("%d && %d = %d\n", a, b, a && b);
    printf("%d || 0 = %d\n", a, a || 0);
    
    return 0;
}
