#include "test.h"

// 复合数据结构 4: 几何形状 (Shape)
// 结构体包含联合体，联合体中包含结构体

typedef enum { SHAPE_CIRCLE, SHAPE_RECT } ShapeType;

struct Circle {
    int radius;
};

struct Rect {
    int width;
    int height;
};

struct Shape {
    ShapeType type;
    union {
        struct Circle circle;
        struct Rect rect;
    } data;
};

double area(struct Shape* s) {
    if (s->type == SHAPE_CIRCLE) {
        return 3.14 * s->data.circle.radius * s->data.circle.radius;
    } else {
        return (double)(s->data.rect.width * s->data.rect.height);
    }
}

int main() {
    struct Shape s1;
    s1.type = SHAPE_CIRCLE;
    s1.data.circle.radius = 5;
    
    struct Shape s2;
    s2.type = SHAPE_RECT;
    s2.data.rect.width = 4;
    s2.data.rect.height = 6;
    
    printf("Circle Area: %f\n", area(&s1));
    printf("Rect Area: %f\n", area(&s2));
    
    return 0;
}

