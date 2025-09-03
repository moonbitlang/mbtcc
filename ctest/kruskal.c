#include "test.h"

#define MAX_NODES 6
#define MAX_EDGES 9

// DSU (Disjoint Set Union) structures and functions
int parent[MAX_NODES];
int sz[MAX_NODES];

void make_set(int v) {
    parent[v] = v;
    sz[v] = 1;
}

int find_set(int v) {
    if (v == parent[v])
        return v;
    parent[v] = find_set(parent[v]); // Path compression
    return parent[v];
}

void union_sets(int a, int b) {
    a = find_set(a);
    b = find_set(b);
    if (a != b) {
        if (sz[a] < sz[b]) {
            int temp = a;
            a = b;
            b = temp;
        }
        parent[b] = a;
        sz[a] = sz[a] + sz[b];
    }
}

// Edge structure for Kruskal's
typedef struct {
    int u, v, weight;
} Edge;

// Simple Bubble Sort for edges
void bubbleSortEdges(Edge edges[], int n) {
    for (int i = 0; i < n - 1; i++) {
        for (int j = 0; j < n - i - 1; j++) {
            if (edges[j].weight > edges[j+1].weight) {
                Edge temp = edges[j];
                edges[j] = edges[j+1];
                edges[j+1] = temp;
            }
        }
    }
}

int main() {
    Edge edges[MAX_EDGES] = {
        {0, 1, 4},
        {0, 2, 3},
        {1, 2, 1},
        {1, 3, 2},
        {2, 3, 4},
        {3, 4, 2},
        {4, 5, 6},
        {2, 5, 5},
        {0, 5, 7}
    };
    int num_edges = MAX_EDGES;
    int num_nodes = MAX_NODES;

    // Initialize DSU for all nodes
    for (int i = 0; i < num_nodes; i++) {
        make_set(i);
    }

    // Sort edges by weight
    bubbleSortEdges(edges, num_edges);

    printf("Edges in MST:\n");
    int mst_weight = 0;
    int edges_count = 0;

    for (int i = 0; i < num_edges && edges_count < num_nodes - 1; i++) {
        Edge current_edge = edges[i];
        if (find_set(current_edge.u) != find_set(current_edge.v)) {
            union_sets(current_edge.u, current_edge.v);
            printf("  %d - %d (Weight: %d)\n", current_edge.u, current_edge.v, current_edge.weight);
            mst_weight += current_edge.weight;
            edges_count++;
        }
    }

    printf("Total MST Weight: %d\n", mst_weight);

    return 0;
}
