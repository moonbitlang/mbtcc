#include "test.h"

// 测试复杂的数值计算和精度控制
double calculate_series_sum(int n) {
    double sum = 0.0;
    for (int i = 1; i <= n; i++) {
        sum += 1.0 / (i * i);
    }
    return sum;
}

double calculate_compound_interest(double principal, double rate, int years) {
    double amount = principal;
    for (int i = 0; i < years; i++) {
        amount = amount * (1.0 + rate);
    }
    return amount;
}

double calculate_polynomial(double x) {
    return x*x*x - 2*x*x + 3*x - 4;
}

int main() {
    // Series calculation
    int n = 1000;
    double series_sum = calculate_series_sum(n);
    printf("Sum of series 1/n^2 for n=1 to %d: %.6f\n", n, series_sum);
    
    // Compound interest calculation
    double principal = 1000.0;
    double rate = 0.05;  // 5% interest
    int years = 10;
    double final_amount = calculate_compound_interest(principal, rate, years);
    printf("Compound interest result: %.2f\n", final_amount);
    
    // Polynomial evaluation
    double x_values[] = {-2.0, -1.0, 0.0, 1.0, 2.0};
    printf("\nPolynomial evaluation (x^3 - 2x^2 + 3x - 4):\n");
    for (int i = 0; i < 5; i++) {
        double x = x_values[i];
        double result = calculate_polynomial(x);
        printf("x = %.1f, result = %.4f\n", x, result);
    }
    
    // Precision demonstration
    double small = 1e-10;
    double large = 1e10;
    double product = small * large;
    printf("\nPrecision test:\n");
    printf("small = %e\n", small);
    printf("large = %e\n", large);
    printf("product = %e\n", product);
    
    return 0;
}
