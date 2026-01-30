#include "test.h"

// 测试if-else条件语句
int main() {
    int score = 85;
    
    printf("Score: %d\n", score);
    
    if (score >= 90) {
        printf("Result: Excellent\n");
    } else if (score >= 80) {
        printf("Result: Good\n");
    } else if (score >= 70) {
        printf("Result: Fair\n");
    } else if (score >= 60) {
        printf("Result: Pass\n");
    } else {
        printf("Result: Fail\n");
    }
    
    // Simple if with boolean expression
    int x = 10;
    int y = 20;
    
    if (x < y && x > 0) {
        printf("Condition met: x is positive and less than y\n");
    }
    
    if (!(x > y)) {
        printf("Condition met: x is not greater than y\n");
    }
    
    return 0;
}
