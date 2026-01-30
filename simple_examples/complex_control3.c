#include "test.h"

// 测试多重条件和循环嵌套
void process_matrix(int rows, int cols) {
    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            if (i == 0 || i == rows - 1) {
                if (j == 0 || j == cols - 1) {
                    printf("C ");
                } else {
                    printf("B ");
                }
            } else if (j == 0 || j == cols - 1) {
                printf("B ");
            } else {
                if ((i + j) % 2 == 0) {
                    if (i % 2 == 0) {
                        printf("X ");
                    } else {
                        printf("O ");
                    }
                } else {
                    if (i % 2 == 0) {
                        printf("O ");
                    } else {
                        printf("X ");
                    }
                }
            }
        }
        printf("\n");
    }
}

void number_pattern(int n) {
    int count = 1;
    
    for (int i = 1; i <= n; i++) {
        for (int j = 1; j <= i; j++) {
            if (count % 3 == 0 && count % 5 == 0) {
                printf("**** ");
            } else if (count % 3 == 0) {
                printf("*** ");
            } else if (count % 5 == 0) {
                printf("** ");
            } else {
                printf("%d ", count);
            }
            count++;
        }
        printf("\n");
    }
}

int main() {
    printf("Matrix pattern 4x4:\n");
    process_matrix(4, 4);
    
    printf("\nNumber pattern with n = 5:\n");
    number_pattern(5);
    
    return 0;
}
