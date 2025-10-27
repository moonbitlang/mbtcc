#include "test.h"

// 测试switch语句
int main() {
    for (int i = 1; i <= 5; i++) {
        printf("Testing number %d:\n", i);
        
        switch (i) {
            case 1:
                printf("First case\n");
                break;
            case 2:
                printf("Second case\n");
                break;
            case 3:
                printf("Third case\n");
                break;
            case 4:
                printf("Fourth case\n");
                break;
            default:
                printf("Default case\n");
                break;
        }
    }
    
    // Switch without break
    printf("\nSwitch fallthrough test:\n");
    int x = 2;
    switch (x) {
        case 1:
            printf("One\n");
        case 2:
            printf("Two\n");
        case 3:
            printf("Three\n");
            break;
        default:
            printf("Other\n");
    }
    
    return 0;
}
