#include "test.h"

// 测试简单枚举
enum Color {
    RED,
    GREEN,
    BLUE
};

enum Month {
    JAN = 1,
    FEB,
    MAR,
    APR,
    MAY,
    JUN
};

int main() {
    enum Color c1 = RED;
    enum Color c2 = GREEN;
    enum Color c3 = BLUE;
    
    printf("Color values: %d, %d, %d\n", c1, c2, c3);
    
    enum Month m1 = JAN;
    enum Month m2 = FEB;
    enum Month m3 = JUN;
    
    printf("Month values: %d, %d, %d\n", m1, m2, m3);
    
    // Enum in conditions
    if (c1 < c2) {
        printf("RED is less than GREEN\n");
    }
    
    if (m3 > m1) {
        printf("JUN is greater than JAN\n");
    }
    
    return 0;
}
