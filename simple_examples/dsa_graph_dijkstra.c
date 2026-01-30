#include "test.h"

// Dijkstra最短路径算法实现
#define MAX_VERTICES 100
#define INF 99999

struct Graph {
    int V;  // Number of vertices
    int adj[MAX_VERTICES][MAX_VERTICES];  // Adjacency matrix
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

void add_edge(struct Graph* graph, int src, int dest, int weight) {
    graph->adj[src][dest] = weight;
    graph->adj[dest][src] = weight;  // For undirected graph
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
            if (graph->adj[i][j] == 0)
                printf("   -");
            else
                printf("%4d", graph->adj[i][j]);
        }
        printf("\n");
    }
    printf("\n");
}

int min_distance(int dist[], int visited[], int V) {
    int min = INF, min_index;
    
    for (int v = 0; v < V; v++) {
        if (!visited[v] && dist[v] <= min) {
            min = dist[v];
            min_index = v;
        }
    }
    
    return min_index;
}

void print_path(int parent[], int j) {
    if (parent[j] == -1)
        return;
    
    print_path(parent, parent[j]);
    printf(" -> %d", j);
}

void print_solution(int dist[], int parent[], int V, int src) {
    printf("Vertex   Distance   Path\n");
    for (int i = 0; i < V; i++) {
        printf("%d\t%d\t\t%d", i, dist[i], src);
        print_path(parent, i);
        printf("\n");
    }
}

void dijkstra(struct Graph* graph, int src) {
    int dist[MAX_VERTICES];
    int visited[MAX_VERTICES];
    int parent[MAX_VERTICES];
    
    // Initialize
    for (int i = 0; i < graph->V; i++) {
        dist[i] = INF;
        visited[i] = 0;
        parent[i] = -1;
    }
    dist[src] = 0;
    
    printf("Starting Dijkstra's algorithm from vertex %d:\n\n", src);
    
    // Find shortest path for all vertices
    for (int count = 0; count < graph->V - 1; count++) {
        int u = min_distance(dist, visited, graph->V);
        visited[u] = 1;
        
        printf("Step %d: Selected vertex %d\n", count + 1, u);
        printf("Current distances: ");
        for (int i = 0; i < graph->V; i++) {
            if (dist[i] == INF)
                printf("INF ");
            else
                printf("%d ", dist[i]);
        }
        printf("\n");
        
        // Update dist value of adjacent vertices
        for (int v = 0; v < graph->V; v++) {
            if (!visited[v] && graph->adj[u][v] &&
                dist[u] != INF &&
                dist[u] + graph->adj[u][v] < dist[v]) {
                dist[v] = dist[u] + graph->adj[u][v];
                parent[v] = u;
                printf("Updated distance to vertex %d: %d\n", v, dist[v]);
            }
        }
        printf("\n");
    }
    
    printf("Final result:\n");
    print_solution(dist, parent, graph->V, src);
}

// Test cases
void test_basic_graph() {
    printf("Testing basic graph:\n");
    struct Graph* graph = create_graph(5);
    
    add_edge(graph, 0, 1, 4);
    add_edge(graph, 0, 2, 8);
    add_edge(graph, 1, 2, 2);
    add_edge(graph, 1, 3, 5);
    add_edge(graph, 2, 3, 5);
    add_edge(graph, 2, 4, 9);
    add_edge(graph, 3, 4, 4);
    
    print_graph(graph);
    dijkstra(graph, 0);
    printf("\n");
    
    free(graph);
}

void test_disconnected_graph() {
    printf("Testing disconnected graph:\n");
    struct Graph* graph = create_graph(4);
    
    add_edge(graph, 0, 1, 4);
    add_edge(graph, 2, 3, 3);
    
    print_graph(graph);
    dijkstra(graph, 0);
    printf("\n");
    
    free(graph);
}

void test_single_vertex() {
    printf("Testing single vertex:\n");
    struct Graph* graph = create_graph(1);
    
    print_graph(graph);
    dijkstra(graph, 0);
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
    
    print_graph(graph);
    dijkstra(graph, 0);
    printf("\n");
    
    free(graph);
}

int main() {
    test_basic_graph();
    test_disconnected_graph();
    test_single_vertex();
    test_complete_graph();
    
    return 0;
}
