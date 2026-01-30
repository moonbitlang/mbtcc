#include "test.h"

// 测试while和do-while循环
int main() {
    int count = 1;
    
    // While loop
    printf("While loop test:\n");
    while (count <= 5) {
        printf("Count: %d\n", count);
        count++;
    }
    
    // Do-while loop
    printf("\nDo-while loop test:\n");
    count = 5;
    do {
        printf("Count: %d\n", count);
        count--;
    } while (count > 0);
    
    // While loop with break
    printf("\nWhile loop with break:\n");
    count = 0;
    while (1) {
        printf("Count: %d\n", count);
        count++;
        if (count >= 3) {
            break;
        }
    }
    
    return 0;
}
