#include "test.h"

// 测试结构体参数传递
struct Point {
    int x;
    int y;
};

struct Rectangle {
    struct Point top_left;
    int width;
    int height;
};

void move_point(struct Point* p, int dx, int dy) {
    p->x += dx;
    p->y += dy;
}

int calculate_area(struct Rectangle r) {
    return r.width * r.height;
}

void print_point(struct Point p) {
    printf("Point(%d, %d)\n", p.x, p.y);
}

void print_rectangle(struct Rectangle r) {
    printf("Rectangle at ");
    print_point(r.top_left);
    printf("Width: %d, Height: %d\n", r.width, r.height);
}

int main() {
    struct Point p = {10, 20};
    printf("Original ");
    print_point(p);
    
    move_point(&p, 5, -5);
    printf("After move ");
    print_point(p);
    
    struct Rectangle r = {{0, 0}, 100, 50};
    print_rectangle(r);
    
    int area = calculate_area(r);
    printf("Area: %d\n", area);
    
    return 0;
}
