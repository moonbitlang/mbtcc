#include "test.h"

// 测试复杂的循环控制和条件组合
void spiral_print(int n) {
    int top = 0, bottom = n - 1;
    int left = 0, right = n - 1;
    int direction = 0;
    int value = 1;
    
    int matrix[20][20];  // Assuming n <= 20
    
    while (top <= bottom && left <= right) {
        if (direction == 0) {  // Left to right
            for (int i = left; i <= right; i++) {
                matrix[top][i] = value++;
            }
            top++;
        }
        else if (direction == 1) {  // Top to bottom
            for (int i = top; i <= bottom; i++) {
                matrix[i][right] = value++;
            }
            right--;
        }
        else if (direction == 2) {  // Right to left
            for (int i = right; i >= left; i--) {
                matrix[bottom][i] = value++;
            }
            bottom--;
        }
        else if (direction == 3) {  // Bottom to top
            for (int i = bottom; i >= top; i--) {
                matrix[i][left] = value++;
            }
            left++;
        }
        direction = (direction + 1) % 4;
    }
    
    // Print the spiral matrix
    for (int i = 0; i < n; i++) {
        for (int j = 0; j < n; j++) {
            printf("%3d ", matrix[i][j]);
        }
        printf("\n");
    }
}

void diamond_pattern(int n) {
    // Upper half
    for (int i = 1; i <= n; i++) {
        // Print spaces
        for (int j = 1; j <= n - i; j++) {
            printf(" ");
        }
        // Print numbers
        for (int j = i; j >= 1; j--) {
            printf("%d", j);
        }
        for (int j = 2; j <= i; j++) {
            printf("%d", j);
        }
        printf("\n");
    }
    
    // Lower half
    for (int i = n - 1; i >= 1; i--) {
        // Print spaces
        for (int j = 1; j <= n - i; j++) {
            printf(" ");
        }
        // Print numbers
        for (int j = i; j >= 1; j--) {
            printf("%d", j);
        }
        for (int j = 2; j <= i; j++) {
            printf("%d", j);
        }
        printf("\n");
    }
}

int main() {
    printf("Spiral matrix 4x4:\n");
    spiral_print(4);
    
    printf("\nDiamond pattern with n = 4:\n");
    diamond_pattern(4);
    
    return 0;
}
