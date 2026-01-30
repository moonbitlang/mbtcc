#include "test.h"

// 0-1背包问题实现
#define MAX_ITEMS 100
#define MAX_WEIGHT 1000

void print_table(int dp[MAX_ITEMS][MAX_WEIGHT], int n, int W,
                int weights[], int values[]) {
    printf("\nDynamic Programming Table:\n");
    printf("    ");
    for (int w = 0; w <= W; w++) {
        printf("%2d ", w);
    }
    printf("\n");
    
    for (int i = 0; i <= n; i++) {
        if (i == 0) printf("   ");
        else printf("%2d ", i);
        
        for (int w = 0; w <= W; w++) {
            printf("%2d ", dp[i][w]);
        }
        printf("\n");
    }
}

void print_selected_items(int dp[MAX_ITEMS][MAX_WEIGHT], int weights[],
                        int values[], int n, int W) {
    int i = n;
    int w = W;
    printf("\nSelected items:\n");
    printf("Item  Weight  Value\n");
    
    while (i > 0 && w > 0) {
        if (dp[i][w] != dp[i-1][w]) {
            printf("%4d %7d %6d\n", i, weights[i-1], values[i-1]);
            w = w - weights[i-1];
        }
        i--;
    }
}

int knapsack(int weights[], int values[], int n, int W) {
    int dp[MAX_ITEMS][MAX_WEIGHT];
    
    // Initialize table
    for (int i = 0; i <= n; i++) {
        for (int w = 0; w <= W; w++) {
            if (i == 0 || w == 0)
                dp[i][w] = 0;
            else if (weights[i-1] <= w)
                dp[i][w] = (values[i-1] + dp[i-1][w-weights[i-1]]) >
                          dp[i-1][w] ? (values[i-1] + dp[i-1][w-weights[i-1]]) :
                          dp[i-1][w];
            else
                dp[i][w] = dp[i-1][w];
        }
    }
    
    print_table(dp, n, W, weights, values);
    print_selected_items(dp, weights, values, n, W);
    
    return dp[n][W];
}

// Test cases
void test_basic_knapsack() {
    printf("Testing basic knapsack:\n");
    int values[] = {60, 100, 120};
    int weights[] = {10, 20, 30};
    int W = 50;
    int n = sizeof(values) / sizeof(values[0]);
    
    printf("Items available:\n");
    printf("Item  Weight  Value\n");
    for (int i = 0; i < n; i++) {
        printf("%4d %7d %6d\n", i+1, weights[i], values[i]);
    }
    printf("Knapsack capacity: %d\n", W);
    
    int max_value = knapsack(weights, values, n, W);
    printf("\nMaximum value: %d\n\n", max_value);
}

void test_no_solution() {
    printf("Testing when no items fit:\n");
    int values[] = {60, 100, 120};
    int weights[] = {10, 20, 30};
    int W = 5;  // Too small capacity
    int n = sizeof(values) / sizeof(values[0]);
    
    printf("Items available:\n");
    printf("Item  Weight  Value\n");
    for (int i = 0; i < n; i++) {
        printf("%4d %7d %6d\n", i+1, weights[i], values[i]);
    }
    printf("Knapsack capacity: %d\n", W);
    
    int max_value = knapsack(weights, values, n, W);
    printf("\nMaximum value: %d\n\n", max_value);
}

void test_exact_fit() {
    printf("Testing exact capacity fit:\n");
    int values[] = {60, 100, 120};
    int weights[] = {10, 20, 20};
    int W = 50;
    int n = sizeof(values) / sizeof(values[0]);
    
    printf("Items available:\n");
    printf("Item  Weight  Value\n");
    for (int i = 0; i < n; i++) {
        printf("%4d %7d %6d\n", i+1, weights[i], values[i]);
    }
    printf("Knapsack capacity: %d\n", W);
    
    int max_value = knapsack(weights, values, n, W);
    printf("\nMaximum value: %d\n\n", max_value);
}

void test_large_values() {
    printf("Testing with large values:\n");
    int values[] = {1000, 2000, 3000, 4000, 5000};
    int weights[] = {10, 20, 30, 40, 50};
    int W = 100;
    int n = sizeof(values) / sizeof(values[0]);
    
    printf("Items available:\n");
    printf("Item  Weight  Value\n");
    for (int i = 0; i < n; i++) {
        printf("%4d %7d %6d\n", i+1, weights[i], values[i]);
    }
    printf("Knapsack capacity: %d\n", W);
    
    int max_value = knapsack(weights, values, n, W);
    printf("\nMaximum value: %d\n\n", max_value);
}

void test_single_item() {
    printf("Testing with single item:\n");
    int values[] = {100};
    int weights[] = {10};
    int W = 15;
    int n = sizeof(values) / sizeof(values[0]);
    
    printf("Items available:\n");
    printf("Item  Weight  Value\n");
    for (int i = 0; i < n; i++) {
        printf("%4d %7d %6d\n", i+1, weights[i], values[i]);
    }
    printf("Knapsack capacity: %d\n", W);
    
    int max_value = knapsack(weights, values, n, W);
    printf("\nMaximum value: %d\n\n", max_value);
}

int main() {
    test_basic_knapsack();
    test_no_solution();
    test_exact_fit();
    test_large_values();
    test_single_item();
    
    return 0;
}
