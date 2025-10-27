#include "test.h"

// 测试复杂的嵌套结构体和联合体
struct Vector2D {
    float x;
    float y;
};

struct Vector3D {
    float x;
    float y;
    float z;
};

union VectorUnion {
    struct Vector2D vec2;
    struct Vector3D vec3;
    float components[3];
};

struct Shape {
    enum {
        CIRCLE,
        RECTANGLE,
        TRIANGLE
    } type;
    
    union {
        struct {
            struct Vector2D center;
            float radius;
        } circle;
        
        struct {
            struct Vector2D position;
            float width;
            float height;
        } rectangle;
        
        struct {
            struct Vector2D points[3];
        } triangle;
    } data;
};

void print_vector2d(struct Vector2D v) {
    printf("(%.2f, %.2f)", v.x, v.y);
}

void print_vector3d(struct Vector3D v) {
    printf("(%.2f, %.2f, %.2f)", v.x, v.y, v.z);
}

void print_shape(struct Shape shape) {
    switch (shape.type) {
        case CIRCLE:
            printf("Circle at ");
            print_vector2d(shape.data.circle.center);
            printf(" with radius %.2f\n", shape.data.circle.radius);
            break;
            
        case RECTANGLE:
            printf("Rectangle at ");
            print_vector2d(shape.data.rectangle.position);
            printf(" with width %.2f and height %.2f\n",
                   shape.data.rectangle.width,
                   shape.data.rectangle.height);
            break;
            
        case TRIANGLE:
            printf("Triangle with points: ");
            for (int i = 0; i < 3; i++) {
                print_vector2d(shape.data.triangle.points[i]);
                printf(" ");
            }
            printf("\n");
            break;
    }
}

int main() {
    // Test VectorUnion
    union VectorUnion vu;
    vu.vec2.x = 1.0f;
    vu.vec2.y = 2.0f;
    printf("Vector2D: ");
    print_vector2d(vu.vec2);
    printf("\n");
    
    vu.vec3.x = 3.0f;
    vu.vec3.y = 4.0f;
    vu.vec3.z = 5.0f;
    printf("Vector3D: ");
    print_vector3d(vu.vec3);
    printf("\n");
    
    // Test Shape structures
    struct Shape shapes[3];
    
    // Create a circle
    shapes[0].type = CIRCLE;
    shapes[0].data.circle.center.x = 0.0f;
    shapes[0].data.circle.center.y = 0.0f;
    shapes[0].data.circle.radius = 5.0f;
    
    // Create a rectangle
    shapes[1].type = RECTANGLE;
    shapes[1].data.rectangle.position.x = 2.0f;
    shapes[1].data.rectangle.position.y = 3.0f;
    shapes[1].data.rectangle.width = 4.0f;
    shapes[1].data.rectangle.height = 6.0f;
    
    // Create a triangle
    shapes[2].type = TRIANGLE;
    shapes[2].data.triangle.points[0].x = 0.0f;
    shapes[2].data.triangle.points[0].y = 0.0f;
    shapes[2].data.triangle.points[1].x = 1.0f;
    shapes[2].data.triangle.points[1].y = 1.0f;
    shapes[2].data.triangle.points[2].x = 0.0f;
    shapes[2].data.triangle.points[2].y = 1.0f;
    
    // Print all shapes
    printf("\nShapes:\n");
    for (int i = 0; i < 3; i++) {
        print_shape(shapes[i]);
    }
    
    return 0;
}
