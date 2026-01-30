#include "test.h"

// 测试for循环
int main() {
    int sum = 0;
    
    // Simple counting loop
    printf("Counting from 1 to 5:\n");
    for (int i = 1; i <= 5; i++) {
        printf("Number: %d\n", i);
        sum += i;
    }
    printf("Sum: %d\n", sum);
    
    // Reverse loop
    printf("\nCounting down from 5 to 1:\n");
    for (int i = 5; i > 0; i--) {
        printf("Number: %d\n", i);
    }
    
    // Loop with step
    printf("\nEven numbers from 2 to 10:\n");
    for (int i = 2; i <= 10; i += 2) {
        printf("Number: %d\n", i);
    }
    
    return 0;
}
