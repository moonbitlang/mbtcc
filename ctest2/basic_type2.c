#include "test.h"

// 测试简单联合体
union Number {
    int i;
    float f;
};

union Data {
    int x;
    char c;
    double d;
};

int main() {
    union Number num;
    
    num.i = 42;
    printf("As integer: %d\n", num.i);
    printf("As float: %f\n", num.f);
    
    num.f = 3.14f;
    printf("As float: %f\n", num.f);
    printf("As integer: %d\n", num.i);
    
    union Data data;
    data.x = 65;
    printf("As integer: %d\n", data.x);
    printf("As char: %c\n", data.c);
    
    data.d = 123.456;
    printf("As double: %f\n", data.d);
    
    return 0;
}
