#include "test.h"

// 测试函数参数传递
void swap_values(int* a, int* b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}

void modify_array(int arr[], int size) {
    for (int i = 0; i < size; i++) {
        arr[i] *= 2;
    }
}

void print_array(int arr[], int size) {
    printf("Array: ");
    for (int i = 0; i < size; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
}

int main() {
    int x = 5, y = 10;
    printf("Before swap: x = %d, y = %d\n", x, y);
    swap_values(&x, &y);
    printf("After swap: x = %d, y = %d\n", x, y);
    
    int numbers[5] = {1, 2, 3, 4, 5};
    printf("Original ");
    print_array(numbers, 5);
    
    modify_array(numbers, 5);
    printf("Modified ");
    print_array(numbers, 5);
    
    return 0;
}
