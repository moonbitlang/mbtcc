#include "test.h"

// 冒泡排序实现
void swap(int* a, int* b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}

void bubble_sort(int arr[], int n) {
    int i, j;
    int swapped;
    
    for (i = 0; i < n - 1; i++) {
        swapped = 0;
        
        // Last i elements are already in place
        for (j = 0; j < n - i - 1; j++) {
            if (arr[j] > arr[j + 1]) {
                swap(&arr[j], &arr[j + 1]);
                swapped = 1;
            }
        }
        
        // If no swapping occurred, array is already sorted
        if (swapped == 0) {
            break;
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
    int arr[] = {64, 34, 25, 12, 22, 11, 90};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    bubble_sort(arr, n);
    
    printf("Sorted array: ");
    print_array(arr, n);
    printf("\n");
}

void test_nearly_sorted_array() {
    printf("Testing nearly sorted array:\n");
    int arr[] = {1, 2, 4, 3, 5, 6, 7};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    bubble_sort(arr, n);
    
    printf("Sorted array: ");
    print_array(arr, n);
    printf("\n");
}

void test_reverse_sorted_array() {
    printf("Testing reverse sorted array:\n");
    int arr[] = {9, 8, 7, 6, 5, 4, 3, 2, 1};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    bubble_sort(arr, n);
    
    printf("Sorted array: ");
    print_array(arr, n);
    printf("\n");
}

void test_array_with_duplicates() {
    printf("Testing array with duplicates:\n");
    int arr[] = {4, 3, 2, 4, 1, 2, 3, 4};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    bubble_sort(arr, n);
    
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
