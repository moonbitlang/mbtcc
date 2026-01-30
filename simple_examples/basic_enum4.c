#include "test.h"

// 测试 enum 作为数组下标
enum Month {
    JAN, FEB, MAR, APR, MAY, JUN,
    JUL, AUG, SEP, OCT, NOV, DEC,
    MONTH_COUNT
};

int main() {
    int days[MONTH_COUNT];
    
    days[JAN] = 31;
    days[FEB] = 28;
    days[MAR] = 31;
    days[APR] = 30;
    
    printf("January days: %d\n", days[JAN]);
    printf("February days: %d\n", days[FEB]);
    printf("March days: %d\n", days[MAR]);
    printf("April days: %d\n", days[APR]);
    
    return 0;
}

