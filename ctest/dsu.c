#include "test.h"

#define MAX_N 10

int parent[MAX_N];
int sz[MAX_N];

void make_set(int v) {
    parent[v] = v;
    sz[v] = 1;
}

int find_set(int v) {
    if (v == parent[v])
        return v;
    // Path compression
    parent[v] = find_set(parent[v]);
    return parent[v];
}

void union_sets(int a, int b) {
    a = find_set(a);
    b = find_set(b);
    if (a != b) {
        // Union by size
        if (sz[a] < sz[b]) {
            int temp = a;
            a = b;
            b = temp;
        }
        parent[b] = a;
        sz[a] = sz[a] + sz[b];
    }
}

int main() {
    for (int i = 0; i < MAX_N; i++) {
        make_set(i);
    }

    union_sets(0, 1);
    union_sets(2, 3);
    union_sets(0, 2);

    // Find parents and print them
    printf("Parent of 1: %d\n", find_set(1)); // Should be same as 0, 2, 3
    printf("Parent of 3: %d\n", find_set(3)); // Should be same as 0, 1, 2

    if (find_set(1) == find_set(3)) {
        printf("1 and 3 are in the same set.\n");
    } else {
        printf("1 and 3 are in different sets.\n");
    }

    if (find_set(1) == find_set(5)) {
        printf("1 and 5 are in the same set.\n");
    } else {
        printf("1 and 5 are in different sets.\n");
    }

    return 0;
}
