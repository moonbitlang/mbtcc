#include "test.h"

// 广度优先搜索实现
#define MAX_VERTICES 100
#define MAX_QUEUE_SIZE 100

// Graph representation using adjacency matrix
struct Graph {
    int V;  // Number of vertices
    int adj[MAX_VERTICES][MAX_VERTICES];
};

// Queue implementation for BFS
struct Queue {
    int items[MAX_QUEUE_SIZE];
    int front;
    int rear;
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

// Queue operations
struct Queue* create_queue() {
    struct Queue* queue = (struct Queue*)malloc(sizeof(struct Queue));
    queue->front = -1;
    queue->rear = -1;
    return queue;
}

int is_empty(struct Queue* queue) {
    return queue->front == -1;
}

void enqueue(struct Queue* queue, int value) {
    if (queue->front == -1) {
        queue->front = 0;
    }
    queue->rear++;
    queue->items[queue->rear] = value;
}

int dequeue(struct Queue* queue) {
    int item = queue->items[queue->front];
    queue->front++;
    if (queue->front > queue->rear) {
        queue->front = queue->rear = -1;
    }
    return item;
}

// BFS implementation
void BFS(struct Graph* graph, int start) {
    int visited[MAX_VERTICES] = {0};
    struct Queue* queue = create_queue();
    
    printf("Starting BFS from vertex %d:\n", start);
    
    visited[start] = 1;
    enqueue(queue, start);
    
    printf("Visit order: ");
    
    while (!is_empty(queue)) {
        int current = dequeue(queue);
        printf("%d ", current);
        
        for (int i = 0; i < graph->V; i++) {
            if (graph->adj[current][i] && !visited[i]) {
                visited[i] = 1;
                enqueue(queue, i);
                printf("\nEdge: %d -> %d", current, i);
            }
        }
    }
    printf("\n\n");
    
    free(queue);
}

// Test different graph structures
void test_simple_path() {
    printf("Testing BFS on a simple path:\n");
    struct Graph* graph = create_graph(4);
    
    add_edge(graph, 0, 1);
    add_edge(graph, 1, 2);
    add_edge(graph, 2, 3);
    
    print_graph(graph);
    BFS(graph, 0);
    
    free(graph);
}

void test_tree() {
    printf("Testing BFS on a tree:\n");
    struct Graph* graph = create_graph(7);
    
    // Create a tree-like structure
    add_edge(graph, 0, 1);
    add_edge(graph, 0, 2);
    add_edge(graph, 1, 3);
    add_edge(graph, 1, 4);
    add_edge(graph, 2, 5);
    add_edge(graph, 2, 6);
    
    print_graph(graph);
    BFS(graph, 0);
    
    free(graph);
}

void test_cycle() {
    printf("Testing BFS on a graph with cycle:\n");
    struct Graph* graph = create_graph(5);
    
    add_edge(graph, 0, 1);
    add_edge(graph, 1, 2);
    add_edge(graph, 2, 3);
    add_edge(graph, 3, 4);
    add_edge(graph, 4, 0);  // Creates a cycle
    
    print_graph(graph);
    BFS(graph, 0);
    
    free(graph);
}

void test_disconnected() {
    printf("Testing BFS on disconnected graph:\n");
    struct Graph* graph = create_graph(6);
    
    // First component
    add_edge(graph, 0, 1);
    add_edge(graph, 1, 2);
    
    // Second component
    add_edge(graph, 3, 4);
    add_edge(graph, 4, 5);
    
    print_graph(graph);
    printf("BFS from vertex 0:\n");
    BFS(graph, 0);
    
    printf("BFS from vertex 3:\n");
    BFS(graph, 3);
    
    free(graph);
}

void test_complete_graph() {
    printf("Testing BFS on complete graph:\n");
    struct Graph* graph = create_graph(4);
    
    // Create edges between all vertices
    for (int i = 0; i < 4; i++) {
        for (int j = i + 1; j < 4; j++) {
            add_edge(graph, i, j);
        }
    }
    
    print_graph(graph);
    BFS(graph, 0);
    
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
