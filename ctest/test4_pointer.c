#include "test.h"

void swap(int* a, int* b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}

int main() {
    // 基本指针操作
    int x = 10;
    int* ptr = &x;
    printf("x = %d, *ptr = %d\n", x, *ptr);
    
    // Modify through pointer
    *ptr = 20;
    printf("After modify: x = %d\n", x);
    
    // Pointer as function parameter
    int a = 5, b = 8;
    printf("Before swap: a = %d, b = %d\n", a, b);
    swap(&a, &b);
    printf("After swap: a = %d, b = %d\n", a, b);
    
    // Simple pointer operations
    int arr[] = {1, 2, 3, 4, 5};
    int* p = arr;
    printf("Access via pointer: %d %d\n", *p, p[1]);
    
    return 0;
}
