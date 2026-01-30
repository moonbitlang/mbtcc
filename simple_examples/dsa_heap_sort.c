#include "test.h"

// 堆排序实现
void swap(int* a, int* b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}

void print_array(int arr[], int n) {
    for (int i = 0; i < n; i++)
        printf("%d ", arr[i]);
    printf("\n");
}

void print_heap_state(int arr[], int n, int i, const char* message) {
    printf("%s: ", message);
    print_array(arr, n);
}

// To heapify a subtree rooted with node i which is an index in arr[]
void heapify(int arr[], int n, int i) {
    int largest = i;     // Initialize largest as root
    int left = 2*i + 1;  // Left child
    int right = 2*i + 2; // Right child
    
    // If left child is larger than root
    if (left < n && arr[left] > arr[largest])
        largest = left;
    
    // If right child is larger than largest so far
    if (right < n && arr[right] > arr[largest])
        largest = right;
    
    // If largest is not root
    if (largest != i) {
        swap(&arr[i], &arr[largest]);
        printf("Heapify swap: %d <-> %d\n", arr[i], arr[largest]);
        print_heap_state(arr, n, i, "After swap");
        
        // Recursively heapify the affected sub-tree
        heapify(arr, n, largest);
    }
}

void heap_sort(int arr[], int n) {
    // Build heap (rearrange array)
    printf("Building max heap:\n");
    for (int i = n / 2 - 1; i >= 0; i--) {
        printf("\nHeapifying subtree rooted at index %d:\n", i);
        heapify(arr, n, i);
    }
    
    print_heap_state(arr, n, 0, "After building max heap");
    
    // One by one extract an element from heap
    printf("\nExtracting elements from heap:\n");
    for (int i = n-1; i > 0; i--) {
        // Move current root to end
        swap(&arr[0], &arr[i]);
        printf("\nMove max element %d to end:\n", arr[i]);
        print_heap_state(arr, n, 0, "After swap");
        
        // call max heapify on the reduced heap
        heapify(arr, i, 0);
    }
}

// Test different cases
void test_random_array() {
    printf("Testing random array:\n");
    int arr[] = {12, 11, 13, 5, 6, 7};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    heap_sort(arr, n);
    
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
    
    heap_sort(arr, n);
    
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
    
    heap_sort(arr, n);
    
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
    
    heap_sort(arr, n);
    
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
    heap_sort(arr1, n1);
    printf("After sorting: ");
    print_array(arr1, n1);
    
    // Two elements
    int arr2[] = {2, 1};
    int n2 = sizeof(arr2) / sizeof(arr2[0]);
    printf("\nTwo element array: ");
    print_array(arr2, n2);
    heap_sort(arr2, n2);
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
