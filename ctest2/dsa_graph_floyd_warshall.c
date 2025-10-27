#include "test.h"

// Floyd-Warshall算法实现
#define MAX_VERTICES 100
#define INF 99999

struct Graph {
    int V;  // Number of vertices
    int dist[MAX_VERTICES][MAX_VERTICES];  // Distance matrix
    int next[MAX_VERTICES][MAX_VERTICES];  // Next vertex matrix
};

struct Graph* create_graph(int V) {
    struct Graph* graph = (struct Graph*)malloc(sizeof(struct Graph));
    graph->V = V;
    
    for (int i = 0; i < V; i++) {
        for (int j = 0; j < V; j++) {
            if (i == j)
                graph->dist[i][j] = 0;
            else
                graph->dist[i][j] = INF;
            graph->next[i][j] = -1;
        }
    }
    
    return graph;
}

void add_edge(struct Graph* graph, int src, int dest, int weight) {
    graph->dist[src][dest] = weight;
    graph->next[src][dest] = dest;
}

void print_matrix(int matrix[MAX_VERTICES][MAX_VERTICES], int V) {
    printf("    ");
    for (int i = 0; i < V; i++) {
        printf("%4d", i);
    }
    printf("\n");
    
    for (int i = 0; i < V; i++) {
        printf("%2d: ", i);
        for (int j = 0; j < V; j++) {
            if (matrix[i][j] == INF)
                printf(" INF");
            else
                printf("%4d", matrix[i][j]);
        }
        printf("\n");
    }
}

void print_path(struct Graph* graph, int src, int dest) {
    if (graph->next[src][dest] == -1) {
        printf("No path exists\n");
        return;
    }
    
    printf("Path from %d to %d: %d", src, dest, src);
    int current = src;
    while (current != dest) {
        current = graph->next[current][dest];
        printf(" -> %d", current);
    }
    printf("\n");
}

void floyd_warshall(struct Graph* graph) {
    int V = graph->V;
    
    printf("Initial distance matrix:\n");
    print_matrix(graph->dist, V);
    printf("\n");
    
    // Main algorithm
    for (int k = 0; k < V; k++) {
        printf("Using vertex %d as intermediate:\n", k);
        
        for (int i = 0; i < V; i++) {
            for (int j = 0; j < V; j++) {
                if (graph->dist[i][k] != INF &&
                    graph->dist[k][j] != INF &&
                    graph->dist[i][k] + graph->dist[k][j] < graph->dist[i][j]) {
                    graph->dist[i][j] = graph->dist[i][k] + graph->dist[k][j];
                    graph->next[i][j] = graph->next[i][k];
                }
            }
        }
        
        print_matrix(graph->dist, V);
        printf("\n");
    }
    
    // Check for negative cycles
    for (int i = 0; i < V; i++) {
        if (graph->dist[i][i] < 0) {
            printf("Graph contains negative cycle\n");
            return;
        }
    }
}

// Test cases
void test_basic_graph() {
    printf("Testing basic graph:\n");
    struct Graph* graph = create_graph(4);
    
    add_edge(graph, 0, 1, 5);
    add_edge(graph, 0, 3, 10);
    add_edge(graph, 1, 2, 3);
    add_edge(graph, 2, 3, 1);
    
    floyd_warshall(graph);
    
    printf("All shortest paths:\n");
    for (int i = 0; i < graph->V; i++) {
        for (int j = 0; j < graph->V; j++) {
            if (i != j) {
                print_path(graph, i, j);
            }
        }
    }
    printf("\n");
    
    free(graph);
}

void test_negative_edges() {
    printf("Testing graph with negative edges:\n");
    struct Graph* graph = create_graph(4);
    
    add_edge(graph, 0, 1, 1);
    add_edge(graph, 1, 2, -3);
    add_edge(graph, 2, 3, 2);
    add_edge(graph, 3, 0, 4);
    
    floyd_warshall(graph);
    
    printf("All shortest paths:\n");
    for (int i = 0; i < graph->V; i++) {
        for (int j = 0; j < graph->V; j++) {
            if (i != j) {
                print_path(graph, i, j);
            }
        }
    }
    printf("\n");
    
    free(graph);
}

void test_disconnected_graph() {
    printf("Testing disconnected graph:\n");
    struct Graph* graph = create_graph(4);
    
    add_edge(graph, 0, 1, 5);
    add_edge(graph, 2, 3, 3);
    
    floyd_warshall(graph);
    
    printf("All shortest paths:\n");
    for (int i = 0; i < graph->V; i++) {
        for (int j = 0; j < graph->V; j++) {
            if (i != j) {
                print_path(graph, i, j);
            }
        }
    }
    printf("\n");
    
    free(graph);
}

void test_complete_graph() {
    printf("Testing complete graph:\n");
    struct Graph* graph = create_graph(4);
    
    add_edge(graph, 0, 1, 1);
    add_edge(graph, 0, 2, 2);
    add_edge(graph, 0, 3, 3);
    add_edge(graph, 1, 2, 4);
    add_edge(graph, 1, 3, 5);
    add_edge(graph, 2, 3, 6);
    add_edge(graph, 1, 0, 1);
    add_edge(graph, 2, 0, 2);
    add_edge(graph, 3, 0, 3);
    add_edge(graph, 2, 1, 4);
    add_edge(graph, 3, 1, 5);
    add_edge(graph, 3, 2, 6);
    
    floyd_warshall(graph);
    
    printf("All shortest paths:\n");
    for (int i = 0; i < graph->V; i++) {
        for (int j = 0; j < graph->V; j++) {
            if (i != j) {
                print_path(graph, i, j);
            }
        }
    }
    printf("\n");
    
    free(graph);
}

int main() {
    test_basic_graph();
    test_negative_edges();
    test_disconnected_graph();
    test_complete_graph();
    
    return 0;
}
