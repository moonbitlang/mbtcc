#include "test.h"

// 测试continue和break语句
int main() {
    // Continue in for loop
    printf("Numbers from 1 to 5, skip 3:\n");
    for (int i = 1; i <= 5; i++) {
        if (i == 3) {
            continue;
        }
        printf("Number: %d\n", i);
    }
    
    // Break in for loop
    printf("\nNumbers until we hit 3:\n");
    for (int i = 1; i <= 5; i++) {
        if (i == 3) {
            break;
        }
        printf("Number: %d\n", i);
    }
    
    // Continue in while loop
    printf("\nEven numbers from 1 to 6:\n");
    int num = 0;
    while (num < 6) {
        num++;
        if (num % 2 != 0) {
            continue;
        }
        printf("Number: %d\n", num);
    }
    
    return 0;
}
