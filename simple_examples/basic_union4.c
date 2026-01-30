#include "test.h"

// 测试 Union 作为函数参数和返回值
union Number {
    int i;
    double d;
};

void print_number_int(union Number n) {
    printf("Number as int: %d\n", n.i);
}

void print_number_double(union Number n) {
    printf("Number as double: %f\n", n.d);
}

union Number create_int(int val) {
    union Number n;
    n.i = val;
    return n;
}

union Number create_double(double val) {
    union Number n;
    n.d = val;
    return n;
}

int main() {
    union Number n1 = create_int(42);
    print_number_int(n1);

    union Number n2 = create_double(3.14159);
    print_number_double(n2);

    return 0;
}
