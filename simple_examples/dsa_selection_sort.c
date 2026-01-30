#include "test.h"

// 选择排序实现
void swap(int* a, int* b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}

void selection_sort(int arr[], int n) {
    int i, j, min_idx;
    
    for (i = 0; i < n - 1; i++) {
        min_idx = i;
        
        // Find the minimum element in unsorted array
        for (j = i + 1; j < n; j++) {
            if (arr[j] < arr[min_idx]) {
                min_idx = j;
            }
        }
        
        // Swap the found minimum element with the first element
        if (min_idx != i) {
            swap(&arr[min_idx], &arr[i]);
        }
        
        // Print array after each pass
        printf("Pass %d: ", i + 1);
        for (int k = 0; k < n; k++) {
            printf("%d ", arr[k]);
        }
        printf("\n");
    }
}

void print_array(int arr[], int size) {
    for (int i = 0; i < size; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
}

// Test different cases
void test_random_array() {
    printf("Testing random array:\n");
    int arr[] = {64, 25, 12, 22, 11};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    selection_sort(arr, n);
    
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
    
    selection_sort(arr, n);
    
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
    
    selection_sort(arr, n);
    
    printf("Sorted array: ");
    print_array(arr, n);
    printf("\n");
}

void test_array_with_duplicates() {
    printf("Testing array with duplicates:\n");
    int arr[] = {3, 1, 2, 1, 2, 3};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    selection_sort(arr, n);
    
    printf("Sorted array: ");
    print_array(arr, n);
    printf("\n");
}

int main() {
    test_random_array();
    test_nearly_sorted_array();
    test_reverse_sorted_array();
    test_array_with_duplicates();
    
    return 0;
}
