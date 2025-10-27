#include "test.h"

// 最长递增子序列实现
void print_array(int arr[], int n) {
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
}

void print_dp_table(int dp[], int n) {
    printf("DP table:\n");
    printf("Index: ");
    for (int i = 0; i < n; i++) {
        printf("%2d ", i);
    }
    printf("\nValue: ");
    for (int i = 0; i < n; i++) {
        printf("%2d ", dp[i]);
    }
    printf("\n");
}

void print_sequence(int arr[], int parent[], int n, int end_index) {
    int sequence[n];
    int length = 0;
    
    // Reconstruct the sequence
    while (end_index != -1) {
        sequence[length++] = arr[end_index];
        end_index = parent[end_index];
    }
    
    // Print in correct order
    printf("Sequence: ");
    for (int i = length - 1; i >= 0; i--) {
        printf("%d ", sequence[i]);
    }
    printf("\n");
}

int lis(int arr[], int n) {
    int dp[n];     // Length of LIS ending at index i
    int parent[n]; // Parent index for reconstructing the sequence
    int max_len = 1;
    int end_index = 0;
    
    // Initialize
    for (int i = 0; i < n; i++) {
        dp[i] = 1;
        parent[i] = -1;
    }
    
    // Build dp table
    printf("Building DP table:\n");
    for (int i = 1; i < n; i++) {
        printf("\nChecking element arr[%d] = %d:\n", i, arr[i]);
        for (int j = 0; j < i; j++) {
            if (arr[i] > arr[j] && dp[i] < dp[j] + 1) {
                dp[i] = dp[j] + 1;
                parent[i] = j;
                printf("Found increasing sequence: dp[%d] = %d\n", i, dp[i]);
            }
        }
        print_dp_table(dp, n);
        
        if (dp[i] > max_len) {
            max_len = dp[i];
            end_index = i;
        }
    }
    
    printf("\nFinal result:\n");
    print_sequence(arr, parent, n, end_index);
    
    return max_len;
}

// Test cases
void test_basic_lis() {
    printf("Testing basic LIS:\n");
    int arr[] = {10, 22, 9, 33, 21, 50, 41, 60, 80};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    printf("Length of LIS: %d\n\n", lis(arr, n));
}

void test_sorted_array() {
    printf("Testing sorted array:\n");
    int arr[] = {1, 2, 3, 4, 5};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    printf("Length of LIS: %d\n\n", lis(arr, n));
}

void test_reverse_sorted() {
    printf("Testing reverse sorted array:\n");
    int arr[] = {5, 4, 3, 2, 1};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    printf("Length of LIS: %d\n\n", lis(arr, n));
}

void test_equal_elements() {
    printf("Testing array with equal elements:\n");
    int arr[] = {2, 2, 2, 2, 2};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    printf("Length of LIS: %d\n\n", lis(arr, n));
}

void test_alternating() {
    printf("Testing alternating sequence:\n");
    int arr[] = {1, 3, 2, 4, 3, 5, 4, 6};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    printf("Length of LIS: %d\n\n", lis(arr, n));
}

void test_single_element() {
    printf("Testing single element array:\n");
    int arr[] = {5};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    print_array(arr, n);
    
    printf("Length of LIS: %d\n\n", lis(arr, n));
}

int main() {
    test_basic_lis();
    test_sorted_array();
    test_reverse_sorted();
    test_equal_elements();
    test_alternating();
    test_single_element();
    
    return 0;
}
