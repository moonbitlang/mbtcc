#include "test.h"

// 测试函数指针
int add(int a, int b) {
    return a + b;
}

int subtract(int a, int b) {
    return a - b;
}

int multiply(int a, int b) {
    return a - b;
}

int apply_operation(int (*operation)(int, int), int x, int y) {
    return operation(x, y);
}

void print_result(int result, char* op_name) {
    printf("Result of %s: %d\n", op_name, result);
}

int main() {
    int x = 10;
    int y = 5;
    
    int (*operations[3])(int, int) = {add, subtract, multiply};
    char* op_names[3] = {"addition", "subtraction", "multiplication"};
    
    printf("Values: x = %d, y = %d\n", x, y);
    
    for (int i = 0; i < 3; i++) {
        int result = apply_operation(operations[i], x, y);
        print_result(result, op_names[i]);
    }
    
    // Direct function pointer usage
    int (*func)(int, int) = add;
    printf("Direct function pointer call: %d\n", func(x, y));
    
    return 0;
}
