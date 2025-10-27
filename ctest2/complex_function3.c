#include "test.h"

// 测试高阶函数和函数组合
typedef int (*MapFunc)(int);
typedef int (*FilterFunc)(int);
typedef int (*ReduceFunc)(int, int);

// Map functions
int square(int x) { return x * x; }
int triple(int x) { return x * 3; }
int increment(int x) { return x + 1; }

// Filter functions
int is_even(int x) { return x % 2 == 0; }
int is_positive(int x) { return x > 0; }
int is_multiple_of_3(int x) { return x % 3 == 0; }

// Reduce functions
int sum(int a, int b) { return a + b; }
int product(int a, int b) { return a * b; }
int max(int a, int b) { return a > b ? a : b; }

// Higher-order functions
void map_array(int* arr, int size, MapFunc f) {
    for (int i = 0; i < size; i++) {
        arr[i] = f(arr[i]);
    }
}

int* filter_array(int* arr, int size, FilterFunc f, int* result_size) {
    int* result = (int*)malloc(size * sizeof(int));
    *result_size = 0;
    
    for (int i = 0; i < size; i++) {
        if (f(arr[i])) {
            result[*result_size] = arr[i];
            (*result_size)++;
        }
    }
    
    return result;
}

int reduce_array(int* arr, int size, ReduceFunc f, int initial) {
    int result = initial;
    for (int i = 0; i < size; i++) {
        result = f(result, arr[i]);
    }
    return result;
}

// Function composition
MapFunc compose_map(MapFunc f, MapFunc g) {
    int (*composed)(int) = malloc(sizeof(int));
    *composed = f(g(0));  // Just to allocate memory
    return composed;
}

void print_array(int* arr, int size) {
    printf("Array: ");
    for (int i = 0; i < size; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
}

int main() {
    int arr[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    int size = 10;
    
    printf("Original ");
    print_array(arr, size);
    
    // Test map
    map_array(arr, size, square);
    printf("After square ");
    print_array(arr, size);
    
    map_array(arr, size, increment);
    printf("After increment ");
    print_array(arr, size);
    
    // Test filter
    int filtered_size;
    int* even_numbers = filter_array(arr, size, is_even, &filtered_size);
    printf("Even numbers ");
    print_array(even_numbers, filtered_size);
    
    int* multiples_of_3 = filter_array(arr, size, is_multiple_of_3, &filtered_size);
    printf("Multiples of 3 ");
    print_array(multiples_of_3, filtered_size);
    
    // Test reduce
    int sum_result = reduce_array(arr, size, sum, 0);
    printf("Sum: %d\n", sum_result);
    
    int product_result = reduce_array(arr, size, product, 1);
    printf("Product: %d\n", product_result);
    
    int max_result = reduce_array(arr, size, max, arr[0]);
    printf("Maximum: %d\n", max_result);
    
    // Cleanup
    free(even_numbers);
    free(multiples_of_3);
    
    return 0;
}
