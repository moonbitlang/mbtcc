#include "test.h"

// 测试基本函数定义和调用
int add(int a, int b) {
    return a + b;
}

int subtract(int a, int b) {
    return a - b;
}

int multiply(int a, int b) {
    return a * b;
}

int divide(int a, int b) {
    return a / b;
}

void print_result(char* operation, int result) {
    printf("%s result: %d\n", operation, result);
}

int main() {
    int x = 20;
    int y = 5;
    
    printf("Values: x = %d, y = %d\n", x, y);
    
    int sum = add(x, y);
    print_result("Addition", sum);
    
    int diff = subtract(x, y);
    print_result("Subtraction", diff);
    
    int prod = multiply(x, y);
    print_result("Multiplication", prod);
    
    int quot = divide(x, y);
    print_result("Division", quot);
    
    return 0;
}
