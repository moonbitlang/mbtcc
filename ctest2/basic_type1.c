#include "test.h"

// 测试简单结构体
struct Point {
    int x;
    int y;
};

struct Rectangle {
    struct Point top_left;
    int width;
    int height;
};

int main() {
    struct Point p1;
    p1.x = 10;
    p1.y = 20;
    
    printf("Point: (%d, %d)\n", p1.x, p1.y);
    
    struct Rectangle rect;
    rect.top_left = p1;
    rect.width = 100;
    rect.height = 50;
    
    printf("Rectangle: position(%d, %d), width=%d, height=%d\n",
           rect.top_left.x, rect.top_left.y,
           rect.width, rect.height);
    
    // Structure assignment
    struct Point p2 = p1;
    printf("Copied point: (%d, %d)\n", p2.x, p2.y);
    
    return 0;
}
