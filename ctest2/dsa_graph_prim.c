#include "test.h"

// Prim最小生成树算法实现
#define MAX_VERTICES 100
#define INF 99999

struct Graph {
    int V;  // Number of vertices
    int graph[MAX_VERTICES][MAX_VERTICES];  // Adjacency matrix
};

struct Graph* create_graph(int V) {
    struct Graph* graph = (struct Graph*)malloc(sizeof(struct Graph));
    graph->V = V;
    
    for (int i = 0; i < V; i++) {
        for (int j = 0; j < V; j++) {
            graph->graph[i][j] = 0;
        }
    }
    
    return graph;
}

void add_edge(struct Graph* graph, int src, int dest, int weight) {
    graph->graph[src][dest] = weight;
    graph->graph[dest][src] = weight;  // For undirected graph
}

void print_graph(struct Graph* graph) {
    printf("Graph adjacency matrix:\n");
    printf("    ");
    for (int i = 0; i < graph->V; i++) {
        printf("%4d", i);
    }
    printf("\n");
    
    for (int i = 0; i < graph->V; i++) {
        printf("%2d: ", i);
        for (int j = 0; j < graph->V; j++) {
            if (graph->graph[i][j] == 0)
                printf("   -");
            else
                printf("%4d", graph->graph[i][j]);
        }
        printf("\n");
    }
    printf("\n");
}

int min_key(int key[], int mst_set[], int V) {
    int min = INF, min_index;
    
    for (int v = 0; v < V; v++) {
        if (mst_set[v] == 0 && key[v] < min) {
            min = key[v];
            min_index = v;
        }
    }
    
    return min_index;
}

void print_mst(int parent[], struct Graph* graph) {
    printf("Minimum Spanning Tree edges:\n");
    printf("Edge \tWeight\n");
    int total_weight = 0;
    for (int i = 1; i < graph->V; i++) {
        printf("%d - %d \t%d\n", parent[i], i, graph->graph[i][parent[i]]);
        total_weight += graph->graph[i][parent[i]];
    }
    printf("Total weight: %d\n", total_weight);
}

void prim_mst(struct Graph* graph) {
    int V = graph->V;
    int parent[V];   // Array to store constructed MST
    int key[V];      // Key values used to pick minimum weight edge
    int mst_set[V];  // To represent set of vertices included in MST
    
    // Initialize all keys as INFINITE
    for (int i = 0; i < V; i++) {
        key[i] = INF;
        mst_set[i] = 0;
    }
    
    // Always include first vertex in MST
    key[0] = 0;      // Make key 0 so that this vertex is picked as first vertex
    parent[0] = -1;  // First node is always root of MST
    
    printf("Building MST:\n");
    
    // The MST will have V vertices
    for (int count = 0; count < V - 1; count++) {
        int u = min_key(key, mst_set, V);
        mst_set[u] = 1;
        
        printf("\nSelected vertex: %d\n", u);
        printf("Current MST vertices: ");
        for (int i = 0; i < V; i++) {
            if (mst_set[i]) printf("%d ", i);
        }
        printf("\n");
        
        // Update key value and parent index of adjacent vertices
        for (int v = 0; v < V; v++) {
            if (graph->graph[u][v] && mst_set[v] == 0 &&
                graph->graph[u][v] < key[v]) {
                parent[v] = u;
                key[v] = graph->graph[u][v];
                printf("Updated key[%d] = %d, parent[%d] = %d\n",
                       v, key[v], v, parent[v]);
            }
        }
        
        printf("Current key values: ");
        for (int i = 0; i < V; i++) {
            if (key[i] == INF)
                printf("INF ");
            else
                printf("%d ", key[i]);
        }
        printf("\n");
    }
    
    printf("\n");
    print_mst(parent, graph);
}

// Test cases
void test_basic_graph() {
    printf("Testing basic graph:\n");
    struct Graph* graph = create_graph(5);
    
    add_edge(graph, 0, 1, 2);
    add_edge(graph, 0, 3, 6);
    add_edge(graph, 1, 2, 3);
    add_edge(graph, 1, 3, 8);
    add_edge(graph, 1, 4, 5);
    add_edge(graph, 2, 4, 7);
    add_edge(graph, 3, 4, 9);
    
    print_graph(graph);
    prim_mst(graph);
    printf("\n");
    
    free(graph);
}

void test_complete_graph() {
    printf("Testing complete graph:\n");
    struct Graph* graph = create_graph(4);
    
    add_edge(graph, 0, 1, 4);
    add_edge(graph, 0, 2, 3);
    add_edge(graph, 0, 3, 1);
    add_edge(graph, 1, 2, 2);
    add_edge(graph, 1, 3, 5);
    add_edge(graph, 2, 3, 6);
    
    print_graph(graph);
    prim_mst(graph);
    printf("\n");
    
    free(graph);
}

void test_disconnected_graph() {
    printf("Testing disconnected graph:\n");
    struct Graph* graph = create_graph(5);
    
    add_edge(graph, 0, 1, 1);
    add_edge(graph, 2, 3, 2);
    add_edge(graph, 3, 4, 3);
    
    print_graph(graph);
    printf("Note: Prim's algorithm may not work correctly for disconnected graphs\n");
    prim_mst(graph);
    printf("\n");
    
    free(graph);
}

void test_same_weight_edges() {
    printf("Testing graph with same weight edges:\n");
    struct Graph* graph = create_graph(4);
    
    add_edge(graph, 0, 1, 1);
    add_edge(graph, 0, 2, 1);
    add_edge(graph, 1, 2, 1);
    add_edge(graph, 1, 3, 1);
    add_edge(graph, 2, 3, 1);
    
    print_graph(graph);
    prim_mst(graph);
    printf("\n");
    
    free(graph);
}

int main() {
    test_basic_graph();
    test_complete_graph();
    test_disconnected_graph();
    test_same_weight_edges();
    
    return 0;
}
