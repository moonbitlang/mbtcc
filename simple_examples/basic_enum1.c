#include "test.h"

// 测试最基本的 enum
enum Color {
    RED,
    GREEN,
    BLUE
};

int main() {
    enum Color c = RED;
    printf("RED: %d\n", c);

    c = GREEN;
    printf("GREEN: %d\n", c);

    c = BLUE;
    printf("BLUE: %d\n", c);

    return 0;
}

