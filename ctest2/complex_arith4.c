#include "test.h"

// 测试复杂的数学计算
double calculate_distance(double x1, double y1, double x2, double y2) {
    double dx = x2 - x1;
    double dy = y2 - y1;
    return sqrt(dx * dx + dy * dy);
}

double calculate_circle_area(double radius) {
    const double PI = 3.14159265358979323846;
    return PI * radius * radius;
}

double calculate_triangle_area(double a, double b, double c) {
    // Using Heron's formula
    double s = (a + b + c) / 2.0;
    return sqrt(s * (s - a) * (s - b) * (s - c));
}

int main() {
    // Distance calculation
    double x1 = 0.0, y1 = 0.0;
    double x2 = 3.0, y2 = 4.0;
    double distance = calculate_distance(x1, y1, x2, y2);
    printf("Distance between points: %.4f\n", distance);
    
    // Circle calculations
    double radius = 5.0;
    double circle_area = calculate_circle_area(radius);
    printf("Circle area with radius %.2f: %.4f\n", radius, circle_area);
    
    // Triangle calculations
    double a = 3.0, b = 4.0, c = 5.0;
    double triangle_area = calculate_triangle_area(a, b, c);
    printf("Triangle area with sides %.2f, %.2f, %.2f: %.4f\n",
           a, b, c, triangle_area);
    
    // Complex geometric calculations
    double total_area = circle_area + triangle_area;
    printf("Total area: %.4f\n", total_area);
    
    double ratio = circle_area / triangle_area;
    printf("Area ratio: %.4f\n", ratio);
    
    return 0;
}
