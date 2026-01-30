#include "test.h"

// 深度优先搜索实现
#define MAX_VERTICES 100

// Graph representation using adjacency matrix
struct Graph {
    int V;  // Number of vertices
    int adj[MAX_VERTICES][MAX_VERTICES];
};

struct Graph* create_graph(int V) {
    struct Graph* graph = (struct Graph*)malloc(sizeof(struct Graph));
    graph->V = V;
    
    for (int i = 0; i < V; i++) {
        for (int j = 0; j < V; j++) {
            graph->adj[i][j] = 0;
        }
    }
    
    return graph;
}

void add_edge(struct Graph* graph, int v, int w) {
    graph->adj[v][w] = 1;
    graph->adj[w][v] = 1;  // For undirected graph
}

void print_graph(struct Graph* graph) {
    printf("Graph adjacency matrix:\n");
    for (int i = 0; i < graph->V; i++) {
        for (int j = 0; j < graph->V; j++) {
            printf("%d ", graph->adj[i][j]);
        }
        printf("\n");
    }
    printf("\n");
}

// DFS implementation
void DFS_util(struct Graph* graph, int v, int visited[], int parent) {
    visited[v] = 1;
    printf("Visiting vertex %d (parent: %d)\n", v, parent);
    
    for (int i = 0; i < graph->V; i++) {
        if (graph->adj[v][i] && !visited[i]) {
            printf("Edge: %d -> %d\n", v, i);
            DFS_util(graph, i, visited, v);
        }
    }
}

void DFS(struct Graph* graph, int start) {
    int visited[MAX_VERTICES] = {0};
    
    printf("Starting DFS from vertex %d:\n", start);
    DFS_util(graph, start, visited, -1);
    printf("\n");
}

// Test different graph structures
void test_simple_path() {
    printf("Testing DFS on a simple path:\n");
    struct Graph* graph = create_graph(4);
    
    add_edge(graph, 0, 1);
    add_edge(graph, 1, 2);
    add_edge(graph, 2, 3);
    
    print_graph(graph);
    DFS(graph, 0);
    
    free(graph);
}

void test_tree() {
    printf("Testing DFS on a tree:\n");
    struct Graph* graph = create_graph(7);
    
    // Create a tree-like structure
    add_edge(graph, 0, 1);
    add_edge(graph, 0, 2);
    add_edge(graph, 1, 3);
    add_edge(graph, 1, 4);
    add_edge(graph, 2, 5);
    add_edge(graph, 2, 6);
    
    print_graph(graph);
    DFS(graph, 0);
    
    free(graph);
}

void test_cycle() {
    printf("Testing DFS on a graph with cycle:\n");
    struct Graph* graph = create_graph(5);
    
    add_edge(graph, 0, 1);
    add_edge(graph, 1, 2);
    add_edge(graph, 2, 3);
    add_edge(graph, 3, 4);
    add_edge(graph, 4, 0);  // Creates a cycle
    
    print_graph(graph);
    DFS(graph, 0);
    
    free(graph);
}

void test_disconnected() {
    printf("Testing DFS on disconnected graph:\n");
    struct Graph* graph = create_graph(6);
    
    // First component
    add_edge(graph, 0, 1);
    add_edge(graph, 1, 2);
    
    // Second component
    add_edge(graph, 3, 4);
    add_edge(graph, 4, 5);
    
    print_graph(graph);
    printf("DFS from vertex 0:\n");
    DFS(graph, 0);
    
    printf("DFS from vertex 3:\n");
    DFS(graph, 3);
    
    free(graph);
}

void test_complete_graph() {
    printf("Testing DFS on complete graph:\n");
    struct Graph* graph = create_graph(4);
    
    // Create edges between all vertices
    for (int i = 0; i < 4; i++) {
        for (int j = i + 1; j < 4; j++) {
            add_edge(graph, i, j);
        }
    }
    
    print_graph(graph);
    DFS(graph, 0);
    
    free(graph);
}

int main() {
    test_simple_path();
    test_tree();
    test_cycle();
    test_disconnected();
    test_complete_graph();
    
    return 0;
}
