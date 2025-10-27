#include "test.h"

// Complex number structure
struct Complex {
    double real;
    double imag;
};

// Nested structure example
struct Circle {
    struct Point {
        double x;
        double y;
    } center;
    double radius;
};

// Structure with array member
struct Matrix {
    int rows;
    int cols;
    int data[3][3];
};

// Function to add complex numbers
struct Complex add_complex(struct Complex a, struct Complex b) {
    struct Complex result;
    result.real = a.real + b.real;
    result.imag = a.imag + b.imag;
    return result;
}

// Function to calculate circle area
double circle_area(struct Circle* c) {
    return 3.14159 * c->radius * c->radius;
}

// Function to initialize matrix
void init_matrix(struct Matrix* m) {
    m->rows = 3;
    m->cols = 3;
    int value = 1;
    for (int i = 0; i < m->rows; i++) {
        for (int j = 0; j < m->cols; j++) {
            m->data[i][j] = value++;
        }
    }
}

int main() {
    // Complex number operations
    struct Complex c1 = {1.0, 2.0};
    struct Complex c2 = {3.0, 4.0};
    struct Complex sum = add_complex(c1, c2);
    printf("Complex sum: %.1f + %.1fi\n", sum.real, sum.imag);
    
    // Circle operations
    struct Circle circle;
    circle.center.x = 0.0;
    circle.center.y = 0.0;
    circle.radius = 5.0;
    printf("Circle area: %.2f\n", circle_area(&circle));
    
    // Matrix operations
    struct Matrix matrix;
    init_matrix(&matrix);
    printf("Matrix contents:\n");
    for (int i = 0; i < matrix.rows; i++) {
        for (int j = 0; j < matrix.cols; j++) {
            printf("%d ", matrix.data[i][j]);
        }
        printf("\n");
    }
    
    return 0;
}
