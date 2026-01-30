#include "test.h"

// 测试 typedef enum
typedef enum {
    FALSE = 0,
    TRUE = 1
} Boolean;

void check_value(int val, Boolean expected) {
    Boolean result = (val > 10) ? TRUE : FALSE;
    if (result == expected) {
        printf("Check passed for val %d\n", val);
    } else {
        printf("Check failed for val %d\n", val);
    }
}

int main() {
    Boolean flag = TRUE;
    printf("Flag is %d\n", flag);
    
    check_value(5, FALSE);
    check_value(15, TRUE);
    
    return 0;
}

