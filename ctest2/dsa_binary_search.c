#include "test.h"

// 二分搜索实现
void print_array(int arr[], int n) {
    printf("Array: ");
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
}

void print_search_step(int arr[], int left, int right, int mid, int target) {
    printf("Searching range [%d, %d], mid = %d (value = %d), target = %d\n",
           left, right, mid, arr[mid], target);
}

// Iterative binary search
int binary_search_iterative(int arr[], int n, int x) {
    int left = 0;
    int right = n - 1;
    
    printf("Starting iterative binary search for %d:\n", x);
    
    while (left <= right) {
        int mid = left + (right - left) / 2;
        print_search_step(arr, left, right, mid, x);
        
        if (arr[mid] == x) {
            printf("Found target at index %d\n", mid);
            return mid;
        }
        
        if (arr[mid] < x) {
            printf("Target is in right half\n");
            left = mid + 1;
        } else {
            printf("Target is in left half\n");
            right = mid - 1;
        }
    }
    
    printf("Target not found\n");
    return -1;
}

// Recursive binary search
int binary_search_recursive_helper(int arr[], int left, int right, int x) {
    if (left <= right) {
        int mid = left + (right - left) / 2;
        print_search_step(arr, left, right, mid, x);
        
        if (arr[mid] == x) {
            printf("Found target at index %d\n", mid);
            return mid;
        }
        
        if (arr[mid] > x) {
            printf("Target is in left half\n");
            return binary_search_recursive_helper(arr, left, mid - 1, x);
        }
        
        printf("Target is in right half\n");
        return binary_search_recursive_helper(arr, mid + 1, right, x);
    }
    
    printf("Target not found\n");
    return -1;
}

int binary_search_recursive(int arr[], int n, int x) {
    printf("Starting recursive binary search for %d:\n", x);
    return binary_search_recursive_helper(arr, 0, n - 1, x);
}

// Test different cases
void test_basic_search() {
    printf("Testing basic search:\n");
    int arr[] = {2, 3, 4, 10, 40};
    int n = sizeof(arr) / sizeof(arr[0]);
    int x = 10;
    
    print_array(arr, n);
    
    printf("\nIterative search:\n");
    int result1 = binary_search_iterative(arr, n, x);
    if (result1 != -1)
        printf("Element %d found at index %d\n", x, result1);
    
    printf("\nRecursive search:\n");
    int result2 = binary_search_recursive(arr, n, x);
    if (result2 != -1)
        printf("Element %d found at index %d\n", x, result2);
    printf("\n");
}

void test_first_last_elements() {
    printf("Testing search for first and last elements:\n");
    int arr[] = {1, 2, 3, 4, 5};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    print_array(arr, n);
    
    // Search first element
    printf("\nSearching first element:\n");
    int result = binary_search_iterative(arr, n, 1);
    if (result != -1)
        printf("First element found at index %d\n", result);
    
    // Search last element
    printf("\nSearching last element:\n");
    result = binary_search_iterative(arr, n, 5);
    if (result != -1)
        printf("Last element found at index %d\n", result);
    printf("\n");
}

void test_missing_element() {
    printf("Testing search for missing element:\n");
    int arr[] = {1, 3, 5, 7, 9};
    int n = sizeof(arr) / sizeof(arr[0]);
    int x = 4;
    
    print_array(arr, n);
    
    printf("\nSearching for %d:\n", x);
    int result = binary_search_recursive(arr, n, x);
    if (result == -1)
        printf("Element %d is not in the array\n", x);
    printf("\n");
}

void test_single_element() {
    printf("Testing search in single element array:\n");
    int arr[] = {5};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    print_array(arr, n);
    
    // Test with element present
    printf("\nSearching for present element:\n");
    int result = binary_search_iterative(arr, n, 5);
    if (result != -1)
        printf("Element 5 found at index %d\n", result);
    
    // Test with element not present
    printf("\nSearching for absent element:\n");
    result = binary_search_iterative(arr, n, 10);
    if (result == -1)
        printf("Element 10 is not in the array\n");
    printf("\n");
}

void test_large_array() {
    printf("Testing search in large sorted array:\n");
    int arr[100];
    for (int i = 0; i < 100; i++) {
        arr[i] = i * 2;  // Even numbers
    }
    
    printf("Array contains even numbers from 0 to 198\n");
    
    // Search for existing element
    int x = 150;
    printf("\nSearching for %d:\n", x);
    int result = binary_search_recursive(arr, 100, x);
    if (result != -1)
        printf("Element %d found at index %d\n", x, result);
    
    // Search for non-existing element
    x = 151;
    printf("\nSearching for %d:\n", x);
    result = binary_search_recursive(arr, 100, x);
    if (result == -1)
        printf("Element %d is not in the array\n", x);
}

int main() {
    test_basic_search();
    test_first_last_elements();
    test_missing_element();
    test_single_element();
    test_large_array();
    
    return 0;
}
