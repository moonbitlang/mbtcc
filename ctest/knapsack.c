#include "test.h"

#define NUM_ITEMS 3
#define CAPACITY 50

int max(int a, int b) {
    if (a > b) {
        return a;
    }
    return b;
}

void knapsack(int W, int wt[], int val[], int n) {
    int i, w;
    int (*K)[W + 1] = malloc(sizeof(int[n + 1][W + 1]));

    if (K == 0) { 
        printf("Memory allocation failed\n");
        return;
    }

    for (i = 0; i <= n; i++) {
        for (w = 0; w <= W; w++) {
            if (i == 0 || w == 0)
                K[i][w] = 0;
            else if (wt[i - 1] <= w)
                K[i][w] = max(val[i - 1] + K[i - 1][w - wt[i - 1]], K[i - 1][w]);
            else
                K[i][w] = K[i - 1][w];
        }
    }
    printf("Max value in knapsack: %d\n", K[n][W]);
    free(K);
}

int main() {
    int val[NUM_ITEMS] = {60, 100, 120};
    int wt[NUM_ITEMS] = {10, 20, 30};
    knapsack(CAPACITY, wt, val, NUM_ITEMS);
    return 0;
}