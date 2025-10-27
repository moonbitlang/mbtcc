#include "test.h"

// 测试函数返回值
int* create_array(int size) {
    int* arr = (int*)malloc(size * sizeof(int));
    for (int i = 0; i < size; i++) {
        arr[i] = i + 1;
    }
    return arr;
}

struct Point {
    int x;
    int y;
};

struct Point create_point(int x, int y) {
    struct Point p;
    p.x = x;
    p.y = y;
    return p;
}

int sum_array(int* arr, int size) {
    int sum = 0;
    for (int i = 0; i < size; i++) {
        sum += arr[i];
    }
    return sum;
}

int main() {
    int size = 5;
    int* numbers = create_array(size);
    
    printf("Created array: ");
    for (int i = 0; i < size; i++) {
        printf("%d ", numbers[i]);
    }
    printf("\n");
    
    int total = sum_array(numbers, size);
    printf("Sum of array: %d\n", total);
    
    struct Point p = create_point(10, 20);
    printf("Created point: (%d, %d)\n", p.x, p.y);
    
    free(numbers);
    return 0;
}
