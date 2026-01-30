#include "test.h"

// 测试 enum 在 switch 语句中的使用
enum Direction {
    UP,
    DOWN,
    LEFT,
    RIGHT
};

const char* get_direction_name(enum Direction d) {
    switch (d) {
        case UP: return "Up";
        case DOWN: return "Down";
        case LEFT: return "Left";
        case RIGHT: return "Right";
        default: return "Invalid";
    }
}

int main() {
    printf("Direction 0: %s\n", get_direction_name(UP));
    printf("Direction 1: %s\n", get_direction_name(DOWN));
    printf("Direction 2: %s\n", get_direction_name(LEFT));
    printf("Direction 3: %s\n", get_direction_name(RIGHT));
    
    return 0;
}

