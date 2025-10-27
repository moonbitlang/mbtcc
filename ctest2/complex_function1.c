#include "test.h"

// 测试函数指针数组和回调函数
typedef int (*Operation)(int, int);
typedef void (*Transformer)(int*, int);

int add(int a, int b) { return a + b; }
int subtract(int a, int b) { return a - b; }
int multiply(int a, int b) { return a * b; }
int divide(int a, int b) { return b != 0 ? a / b : 0; }

void double_value(int* arr, int index) {
    arr[index] *= 2;
}

void square_value(int* arr, int index) {
    arr[index] *= arr[index];
}

void cube_value(int* arr, int index) {
    arr[index] = arr[index] * arr[index] * arr[index];
}

int apply_operation(Operation op, int a, int b) {
    return op(a, b);
}

void transform_array(int* arr, int size, Transformer transform) {
    for (int i = 0; i < size; i++) {
        transform(arr, i);
    }
}

void print_array(int* arr, int size) {
    printf("Array: ");
    for (int i = 0; i < size; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
}

int main() {
    // Test operation function pointers
    Operation operations[] = {add, subtract, multiply, divide};
    char* op_names[] = {"Addition", "Subtraction", "Multiplication", "Division"};
    
    int a = 10, b = 5;
    printf("Values: a = %d, b = %d\n", a, b);
    
    for (int i = 0; i < 4; i++) {
        int result = apply_operation(operations[i], a, b);
        printf("%s result: %d\n", op_names[i], result);
    }
    
    // Test transformer function pointers
    int arr[] = {1, 2, 3, 4, 5};
    int size = 5;
    
    Transformer transformers[] = {double_value, square_value, cube_value};
    char* transform_names[] = {"Double", "Square", "Cube"};
    
    for (int i = 0; i < 3; i++) {
        printf("\nApplying %s transformation:\n", transform_names[i]);
        print_array(arr, size);
        transform_array(arr, size, transformers[i]);
        print_array(arr, size);
    }
    
    return 0;
}
