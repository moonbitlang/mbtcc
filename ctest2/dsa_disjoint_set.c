#include "test.h"

// 并查集实现
#define MAX_ELEMENTS 100

struct DisjointSet {
    int parent[MAX_ELEMENTS];
    int rank[MAX_ELEMENTS];
    int size;
};

void init_set(struct DisjointSet* ds, int n) {
    ds->size = n;
    for (int i = 0; i < n; i++) {
        ds->parent[i] = i;  // Each element is its own parent initially
        ds->rank[i] = 0;    // Initial rank is 0
    }
}

// Find with path compression
int find(struct DisjointSet* ds, int x) {
    if (ds->parent[x] != x) {
        ds->parent[x] = find(ds, ds->parent[x]);  // Path compression
    }
    return ds->parent[x];
}

// Union by rank
void union_sets(struct DisjointSet* ds, int x, int y) {
    int root_x = find(ds, x);
    int root_y = find(ds, y);
    
    if (root_x == root_y) {
        return;
    }
    
    // Attach smaller rank tree under root of higher rank tree
    if (ds->rank[root_x] < ds->rank[root_y]) {
        ds->parent[root_x] = root_y;
    }
    else if (ds->rank[root_x] > ds->rank[root_y]) {
        ds->parent[root_y] = root_x;
    }
    else {
        ds->parent[root_y] = root_x;
        ds->rank[root_x]++;
    }
}

int is_same_set(struct DisjointSet* ds, int x, int y) {
    return find(ds, x) == find(ds, y);
}

void print_sets(struct DisjointSet* ds) {
    printf("Sets: ");
    for (int i = 0; i < ds->size; i++) {
        printf("%d->%d ", i, find(ds, i));
    }
    printf("\n");
}

// Test connected components in a graph
void test_connected_components() {
    struct DisjointSet ds;
    int n = 7;  // Number of vertices
    init_set(&ds, n);
    
    printf("Testing connected components:\n");
    
    // Add edges
    printf("Adding edges: (0,1), (1,2), (3,4), (5,6)\n");
    union_sets(&ds, 0, 1);
    union_sets(&ds, 1, 2);
    union_sets(&ds, 3, 4);
    union_sets(&ds, 5, 6);
    
    print_sets(&ds);
    
    printf("Are vertices 0 and 2 connected? %s\n",
           is_same_set(&ds, 0, 2) ? "Yes" : "No");
    printf("Are vertices 0 and 3 connected? %s\n",
           is_same_set(&ds, 0, 3) ? "Yes" : "No");
    
    printf("\nAdding edge: (2,3)\n");
    union_sets(&ds, 2, 3);
    print_sets(&ds);
}

// Test cycle detection in a graph
int has_cycle(struct DisjointSet* ds, int edges[][2], int num_edges) {
    for (int i = 0; i < num_edges; i++) {
        int x = edges[i][0];
        int y = edges[i][1];
        
        int root_x = find(ds, x);
        int root_y = find(ds, y);
        
        if (root_x == root_y) {
            return 1;  // Cycle detected
        }
        
        union_sets(ds, x, y);
    }
    return 0;  // No cycle
}

void test_cycle_detection() {
    struct DisjointSet ds;
    int n = 5;  // Number of vertices
    init_set(&ds, n);
    
    int edges[][2] = {
        {0, 1},
        {1, 2},
        {2, 3},
        {3, 4},
        {4, 1}  // This edge creates a cycle
    };
    
    printf("\nTesting cycle detection:\n");
    printf("Graph has cycle? %s\n",
           has_cycle(&ds, edges, 5) ? "Yes" : "No");
}

int main() {
    // Test connected components
    test_connected_components();
    
    // Test cycle detection
    test_cycle_detection();
    
    return 0;
}
