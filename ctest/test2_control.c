#include "test.h"

int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}

int main() {
    // if-else 控制
    int x = 10;
    if (x > 5) {
        printf("x > 5\n");
    } else {
        printf("x <= 5\n");
    }
    
    // for 循环
    printf("For loop 1 to 5: ");
    for (int i = 1; i <= 5; i++) {
        printf("%d ", i);
    }
    printf("\n");
    
    // while loop
    printf("While loop 5 to 1: ");
    int j = 5;
    while (j > 0) {
        printf("%d ", j);
        j--;
    }
    printf("\n");
    
    // Function call and recursion
    printf("Factorial of 5: %d\n", factorial(5));
    
    return 0;
}
