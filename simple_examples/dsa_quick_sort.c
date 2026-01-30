#include "test.h"

// 快速排序实现
void swap(int* a, int* b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}

void print_array(int arr[], int size) {
    for (int i = 0; i < size; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
}

void print_partition_step(int arr[], int size, int low, int high, int pivot) {
    printf("Partition step: pivot = %d, ", pivot);
    for (int i = 0; i < size; i++) {
        if (i == low) printf("[ ");
        printf("%d ", arr[i]);
        if (i == high) printf("] ");
    }
    printf("\n");
}

// Partition using last element as pivot
int partition(int arr[], int low, int high, int size) {
    int pivot = arr[high];
    int i = (low - 1);
    
    printf("\nChoosing pivot: %d\n", pivot);
    
    for (int j = low; j <= high - 1; j++) {
        if (arr[j] < pivot) {
            i++;
            swap(&arr[i], &arr[j]);
        }
    }
    swap(&arr[i + 1], &arr[high]);
    
    print_partition_step(arr, size, low, high, pivot);
    return (i + 1);
}

void quick_sort_recursive(int arr[], int low, int high, int size) {
    if (low < high) {
        int pi = partition(arr, low, high, size);
        
        quick_sort_recursive(arr, low, pi - 1, size);
        quick_sort_recursive(arr, pi + 1, high, size);
    }
}

void quick_sort(int arr[], int n) {
    quick_sort_recursive(arr, 0, n - 1, n);
}

// Test different cases
void test_random_array() {
    printf("Testing random array:\n");
    int arr[] = {10, 7, 8, 9, 1, 5};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    quick_sort(arr, n);
    
    printf("Sorted array: ");
    print_array(arr, n);
    printf("\n");
}

void test_nearly_sorted_array() {
    printf("Testing nearly sorted array:\n");
    int arr[] = {1, 2, 4, 3, 5, 6};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    quick_sort(arr, n);
    
    printf("Sorted array: ");
    print_array(arr, n);
    printf("\n");
}

void test_reverse_sorted_array() {
    printf("Testing reverse sorted array:\n");
    int arr[] = {6, 5, 4, 3, 2, 1};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    quick_sort(arr, n);
    
    printf("Sorted array: ");
    print_array(arr, n);
    printf("\n");
}

void test_array_with_duplicates() {
    printf("Testing array with duplicates:\n");
    int arr[] = {4, 2, 4, 1, 2, 4};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    quick_sort(arr, n);
    
    printf("Sorted array: ");
    print_array(arr, n);
    printf("\n");
}

void test_small_arrays() {
    printf("Testing small arrays:\n");
    
    // Single element
    int arr1[] = {1};
    int n1 = sizeof(arr1) / sizeof(arr1[0]);
    printf("Single element array: ");
    print_array(arr1, n1);
    quick_sort(arr1, n1);
    printf("After sorting: ");
    print_array(arr1, n1);
    
    // Two elements
    int arr2[] = {2, 1};
    int n2 = sizeof(arr2) / sizeof(arr2[0]);
    printf("\nTwo element array: ");
    print_array(arr2, n2);
    quick_sort(arr2, n2);
    printf("After sorting: ");
    print_array(arr2, n2);
    printf("\n");
}

int main() {
    test_random_array();
    test_nearly_sorted_array();
    test_reverse_sorted_array();
    test_array_with_duplicates();
    test_small_arrays();
    
    return 0;
}
