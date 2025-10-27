#include "test.h"

void swap(int* a, int* b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}

int main() {
    // Basic pointer operations
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
    
    // Pointer arithmetic
    int arr[] = {1, 2, 3, 4, 5};
    int* p = arr;
    printf("Array via pointer arithmetic:\n");
    for (int i = 0; i < 5; i++) {
        printf("*(p + %d) = %d\n", i, *(p + i));
    }
    
    // Pointer increment/decrement
    printf("\nPointer increment:\n");
    p = arr;  // Reset pointer to start
    for (int i = 0; i < 5; i++) {
        printf("%d ", *p);
        p++;
    }
    printf("\n");
    
    // Array of pointers
    int* ptr_arr[3];
    int val1 = 100, val2 = 200, val3 = 300;
    ptr_arr[0] = &val1;
    ptr_arr[1] = &val2;
    ptr_arr[2] = &val3;
    printf("\nArray of pointers:\n");
    for (int i = 0; i < 3; i++) {
        printf("*ptr_arr[%d] = %d\n", i, *ptr_arr[i]);
    }
    
    return 0;
}
