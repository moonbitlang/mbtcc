#include "test.h"

// 插入排序实现
void insertion_sort(int arr[], int n) {
    int i, key, j;
    
    for (i = 1; i < n; i++) {
        key = arr[i];
        j = i - 1;
        
        // Move elements of arr[0..i-1] that are greater than key
        // to one position ahead of their current position
        while (j >= 0 && arr[j] > key) {
            arr[j + 1] = arr[j];
            j = j - 1;
        }
        arr[j + 1] = key;
        
        // Print array after each pass
        printf("Pass %d: ", i);
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
    int arr[] = {12, 11, 13, 5, 6};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    insertion_sort(arr, n);
    
    printf("Sorted array: ");
    print_array(arr, n);
    printf("\n");
}

void test_nearly_sorted_array() {
    printf("Testing nearly sorted array:\n");
    int arr[] = {1, 3, 2, 4, 5, 6};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    insertion_sort(arr, n);
    
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
    
    insertion_sort(arr, n);
    
    printf("Sorted array: ");
    print_array(arr, n);
    printf("\n");
}

void test_array_with_duplicates() {
    printf("Testing array with duplicates:\n");
    int arr[] = {4, 3, 2, 4, 1, 2};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    insertion_sort(arr, n);
    
    printf("Sorted array: ");
    print_array(arr, n);
    printf("\n");
}

// Test array with single element
void test_single_element() {
    printf("Testing array with single element:\n");
    int arr[] = {1};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    insertion_sort(arr, n);
    
    printf("Sorted array: ");
    print_array(arr, n);
    printf("\n");
}

int main() {
    test_random_array();
    test_nearly_sorted_array();
    test_reverse_sorted_array();
    test_array_with_duplicates();
    test_single_element();
    
    return 0;
}
