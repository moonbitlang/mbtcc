#include "test.h"

struct Point {
    int x;
    int y;
};

struct Rectangle {
    struct Point top_left;
    int width;
    int height;
};

int calculate_area(struct Rectangle* rect) {
    return rect->width * rect->height;
}

int main() {
    // Basic struct operations
    struct Point p1;
    p1.x = 10;
    p1.y = 20;
    printf("Point coordinates: (%d, %d)\n", p1.x, p1.y);
    
    // Struct pointer
    struct Point* pp = &p1;
    printf("Access via pointer: (%d, %d)\n", pp->x, pp->y);
    
    // Nested struct
    struct Rectangle rect;
    rect.top_left = p1;
    rect.width = 5;
    rect.height = 3;
    
    printf("Rectangle info:\n");
    printf("Top-left: (%d, %d)\n", rect.top_left.x, rect.top_left.y);
    printf("Width: %d, Height: %d\n", rect.width, rect.height);
    printf("Area: %d\n", calculate_area(&rect));
    
    return 0;
}