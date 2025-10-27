#include "test.h"

// 归并排序实现
void print_array(int arr[], int size) {
    for (int i = 0; i < size; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
}

void print_merge_step(int arr[], int l, int m, int r) {
    printf("Merging subarrays: ");
    printf("Left [");
    for (int i = l; i <= m; i++) {
        printf("%d ", arr[i]);
    }
    printf("] Right [");
    for (int i = m + 1; i <= r; i++) {
        printf("%d ", arr[i]);
    }
    printf("]\n");
}

void merge(int arr[], int l, int m, int r) {
    int i, j, k;
    int n1 = m - l + 1;
    int n2 = r - m;
    
    // Create temp arrays
    int L[n1], R[n2];
    
    // Copy data to temp arrays L[] and R[]
    for (i = 0; i < n1; i++)
        L[i] = arr[l + i];
    for (j = 0; j < n2; j++)
        R[j] = arr[m + 1 + j];
    
    print_merge_step(arr, l, m, r);
    
    // Merge the temp arrays back into arr[l..r]
    i = 0;
    j = 0;
    k = l;
    while (i < n1 && j < n2) {
        if (L[i] <= R[j]) {
            arr[k] = L[i];
            i++;
        }
        else {
            arr[k] = R[j];
            j++;
        }
        k++;
    }
    
    // Copy the remaining elements of L[]
    while (i < n1) {
        arr[k] = L[i];
        i++;
        k++;
    }
    
    // Copy the remaining elements of R[]
    while (j < n2) {
        arr[k] = R[j];
        j++;
        k++;
    }
    
    printf("After merging: ");
    for (i = l; i <= r; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
}

void merge_sort_recursive(int arr[], int l, int r) {
    if (l < r) {
        int m = l + (r - l) / 2;
        
        printf("\nDividing array at index %d: ", m);
        for (int i = l; i <= r; i++) {
            printf("%d ", arr[i]);
        }
        printf("\n");
        
        merge_sort_recursive(arr, l, m);
        merge_sort_recursive(arr, m + 1, r);
        
        merge(arr, l, m, r);
    }
}

void merge_sort(int arr[], int n) {
    merge_sort_recursive(arr, 0, n - 1);
}

// Test different cases
void test_random_array() {
    printf("Testing random array:\n");
    int arr[] = {12, 11, 13, 5, 6, 7};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    merge_sort(arr, n);
    
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
    
    merge_sort(arr, n);
    
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
    
    merge_sort(arr, n);
    
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
    
    merge_sort(arr, n);
    
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
    merge_sort(arr1, n1);
    printf("After sorting: ");
    print_array(arr1, n1);
    
    // Two elements
    int arr2[] = {2, 1};
    int n2 = sizeof(arr2) / sizeof(arr2[0]);
    printf("\nTwo element array: ");
    print_array(arr2, n2);
    merge_sort(arr2, n2);
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
