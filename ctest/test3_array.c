#include "test.h"

void print_array(int arr[], int size) {
    for (int i = 0; i < size; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
}

int main() {
    // 1D array
    int arr1[5] = {1, 2, 3, 4, 5};
    printf("1D array: ");
    print_array(arr1, 5);
    
    // Modify array element
    arr1[2] = 30;
    printf("Modified array: ");
    print_array(arr1, 5);
    
    // Array as parameter
    int sum = 0;
    for (int i = 0; i < 5; i++) {
        sum += arr1[i];
    }
    printf("Array sum: %d\n", sum);
    
    // Simple 2D array
    int arr2[2][3] = {{1, 2, 3}, {4, 5, 6}};
    printf("2D array:\n");
    for (int i = 0; i < 2; i++) {
        for (int j = 0; j < 3; j++) {
            printf("%d ", arr2[i][j]);
        }
        printf("\n");
    }
    
    return 0;
}
