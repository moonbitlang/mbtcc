#include "test.h"

// 线性搜索实现
int linear_search(int arr[], int n, int x) {
    printf("Searching for %d:\n", x);
    
    for (int i = 0; i < n; i++) {
        printf("Checking index %d: %d\n", i, arr[i]);
        if (arr[i] == x) {
            return i;
        }
    }
    return -1;
}

void print_array(int arr[], int n) {
    printf("Array: ");
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
}

// Test different cases
void test_basic_search() {
    printf("Testing basic search:\n");
    int arr[] = {2, 3, 4, 10, 40};
    int n = sizeof(arr) / sizeof(arr[0]);
    int x = 10;
    
    print_array(arr, n);
    
    int result = linear_search(arr, n, x);
    if (result == -1)
        printf("Element %d is not present in array\n", x);
    else
        printf("Element %d is present at index %d\n", x, result);
    printf("\n");
}

void test_first_element() {
    printf("Testing search for first element:\n");
    int arr[] = {10, 20, 30, 40, 50};
    int n = sizeof(arr) / sizeof(arr[0]);
    int x = 10;
    
    print_array(arr, n);
    
    int result = linear_search(arr, n, x);
    if (result == -1)
        printf("Element %d is not present in array\n", x);
    else
        printf("Element %d is present at index %d\n", x, result);
    printf("\n");
}

void test_last_element() {
    printf("Testing search for last element:\n");
    int arr[] = {10, 20, 30, 40, 50};
    int n = sizeof(arr) / sizeof(arr[0]);
    int x = 50;
    
    print_array(arr, n);
    
    int result = linear_search(arr, n, x);
    if (result == -1)
        printf("Element %d is not present in array\n", x);
    else
        printf("Element %d is present at index %d\n", x, result);
    printf("\n");
}

void test_missing_element() {
    printf("Testing search for missing element:\n");
    int arr[] = {10, 20, 30, 40, 50};
    int n = sizeof(arr) / sizeof(arr[0]);
    int x = 25;
    
    print_array(arr, n);
    
    int result = linear_search(arr, n, x);
    if (result == -1)
        printf("Element %d is not present in array\n", x);
    else
        printf("Element %d is present at index %d\n", x, result);
    printf("\n");
}

void test_duplicate_elements() {
    printf("Testing search with duplicate elements:\n");
    int arr[] = {10, 20, 10, 30, 10, 40, 50};
    int n = sizeof(arr) / sizeof(arr[0]);
    int x = 10;
    
    print_array(arr, n);
    
    int result = linear_search(arr, n, x);
    if (result == -1)
        printf("Element %d is not present in array\n", x);
    else
        printf("Element %d is present at index %d (first occurrence)\n", x, result);
    printf("\n");
}

void test_single_element() {
    printf("Testing search in single element array:\n");
    int arr[] = {5};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    print_array(arr, n);
    
    // Test with element present
    int x = 5;
    int result = linear_search(arr, n, x);
    if (result == -1)
        printf("Element %d is not present in array\n", x);
    else
        printf("Element %d is present at index %d\n", x, result);
    
    // Test with element not present
    x = 10;
    result = linear_search(arr, n, x);
    if (result == -1)
        printf("Element %d is not present in array\n", x);
    else
        printf("Element %d is present at index %d\n", x, result);
    printf("\n");
}

int main() {
    test_basic_search();
    test_first_element();
    test_last_element();
    test_missing_element();
    test_duplicate_elements();
    test_single_element();
    
    return 0;
}
