#include "test.h"

// 测试嵌套循环和条件语句
void print_pattern(int n) {
    for (int i = 1; i <= n; i++) {
        for (int j = 1; j <= n; j++) {
            if (i == 1 || i == n || j == 1 || j == n) {
                printf("* ");
            } else if (i == j || i + j == n + 1) {
                printf("+ ");
            } else {
                printf("  ");
            }
        }
        printf("\n");
    }
}

int find_special_number(int start, int end) {
    for (int i = start; i <= end; i++) {
        if (i % 3 == 0 && i % 5 == 0) {
            continue;
        }
        
        if (i % 3 == 0) {
            printf("Number divisible by 3: %d\n", i);
        } else if (i % 5 == 0) {
            printf("Number divisible by 5: %d\n", i);
        }
        
        if (i % 7 == 0) {
            printf("Found number divisible by 7: %d\n", i);
            break;
        }
    }
    return 0;
}

int main() {
    printf("Pattern with n = 5:\n");
    print_pattern(5);
    
    printf("\nFinding special numbers between 1 and 20:\n");
    find_special_number(1, 20);
    
    return 0;
}
