#include "test.h"

// Kruskal最小生成树算法实现
struct Edge {
    int src, dest, weight;
};

struct Graph {
    int V, E;
    struct Edge* edges;
};

struct Subset {
    int parent;
    int rank;
};

struct Graph* create_graph(int V, int E) {
    struct Graph* graph = (struct Graph*)malloc(sizeof(struct Graph));
    graph->V = V;
    graph->E = E;
    graph->edges = (struct Edge*)malloc(E * sizeof(struct Edge));
    return graph;
}

void add_edge(struct Graph* graph, int index,
             int src, int dest, int weight) {
    graph->edges[index].src = src;
    graph->edges[index].dest = dest;
    graph->edges[index].weight = weight;
}

// Find set of an element i (uses path compression)
int find(struct Subset subsets[], int i) {
    if (subsets[i].parent != i)
        subsets[i].parent = find(subsets, subsets[i].parent);
    return subsets[i].parent;
}

// Union of two sets (uses union by rank)
void union_sets(struct Subset subsets[], int x, int y) {
    int xroot = find(subsets, x);
    int yroot = find(subsets, y);
    
    if (subsets[xroot].rank < subsets[yroot].rank)
        subsets[xroot].parent = yroot;
    else if (subsets[xroot].rank > subsets[yroot].rank)
        subsets[yroot].parent = xroot;
    else {
        subsets[yroot].parent = xroot;
        subsets[xroot].rank++;
    }
}

// Compare function for qsort
int compare_edges(const void* a, const void* b) {
    return ((struct Edge*)a)->weight - ((struct Edge*)b)->weight;
}

void print_edge(struct Edge edge) {
    printf("(%d -- %d) with weight %d\n",
           edge.src, edge.dest, edge.weight);
}

void kruskal_mst(struct Graph* graph) {
    int V = graph->V;
    struct Edge result[V];
    int e = 0;  // Index for result[]
    int i = 0;  // Index for sorted edges
    
    // Step 1: Sort edges by weight
    qsort(graph->edges, graph->E, sizeof(graph->edges[0]), compare_edges);
    
    printf("Sorted edges:\n");
    for (int j = 0; j < graph->E; j++) {
        print_edge(graph->edges[j]);
    }
    printf("\n");
    
    // Create V subsets with single elements
    struct Subset* subsets = (struct Subset*)malloc(V * sizeof(struct Subset));
    for (int v = 0; v < V; v++) {
        subsets[v].parent = v;
        subsets[v].rank = 0;
    }
    
    printf("Building MST:\n");
    
    while (e < V - 1 && i < graph->E) {
        struct Edge next_edge = graph->edges[i++];
        
        int x = find(subsets, next_edge.src);
        int y = find(subsets, next_edge.dest);
        
        printf("Considering edge ");
        print_edge(next_edge);
        
        if (x != y) {
            result[e++] = next_edge;
            union_sets(subsets, x, y);
            printf("Added to MST\n");
        } else {
            printf("Skipped (would create cycle)\n");
        }
        printf("\n");
    }
    
    printf("Minimum Spanning Tree:\n");
    int total_weight = 0;
    for (i = 0; i < e; i++) {
        print_edge(result[i]);
        total_weight += result[i].weight;
    }
    printf("Total weight: %d\n", total_weight);
    
    free(subsets);
}

// Test cases
void test_basic_graph() {
    printf("Testing basic graph:\n");
    int V = 4, E = 5;
    struct Graph* graph = create_graph(V, E);
    
    add_edge(graph, 0, 0, 1, 10);
    add_edge(graph, 1, 0, 2, 6);
    add_edge(graph, 2, 0, 3, 5);
    add_edge(graph, 3, 1, 3, 15);
    add_edge(graph, 4, 2, 3, 4);
    
    kruskal_mst(graph);
    printf("\n");
    
    free(graph->edges);
    free(graph);
}

void test_disconnected_graph() {
    printf("Testing disconnected graph:\n");
    int V = 5, E = 3;
    struct Graph* graph = create_graph(V, E);
    
    add_edge(graph, 0, 0, 1, 1);
    add_edge(graph, 1, 2, 3, 2);
    add_edge(graph, 2, 3, 4, 3);
    
    kruskal_mst(graph);
    printf("\n");
    
    free(graph->edges);
    free(graph);
}

void test_complete_graph() {
    printf("Testing complete graph:\n");
    int V = 4, E = 6;
    struct Graph* graph = create_graph(V, E);
    
    add_edge(graph, 0, 0, 1, 4);
    add_edge(graph, 1, 0, 2, 3);
    add_edge(graph, 2, 0, 3, 1);
    add_edge(graph, 3, 1, 2, 2);
    add_edge(graph, 4, 1, 3, 5);
    add_edge(graph, 5, 2, 3, 6);
    
    kruskal_mst(graph);
    printf("\n");
    
    free(graph->edges);
    free(graph);
}

void test_same_weight_edges() {
    printf("Testing graph with same weight edges:\n");
    int V = 4, E = 5;
    struct Graph* graph = create_graph(V, E);
    
    add_edge(graph, 0, 0, 1, 1);
    add_edge(graph, 1, 0, 2, 1);
    add_edge(graph, 2, 1, 2, 1);
    add_edge(graph, 3, 1, 3, 1);
    add_edge(graph, 4, 2, 3, 1);
    
    kruskal_mst(graph);
    printf("\n");
    
    free(graph->edges);
    free(graph);
}

int main() {
    test_basic_graph();
    test_disconnected_graph();
    test_complete_graph();
    test_same_weight_edges();
    
    return 0;
}
