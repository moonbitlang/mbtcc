#include "test.h"

// 图的邻接表实现
#define MAX_VERTICES 100

struct Node {
    int vertex;
    struct Node* next;
};

struct Graph {
    struct Node* adj_list[MAX_VERTICES];
    int num_vertices;
};

struct Node* create_node(int v) {
    struct Node* new_node = (struct Node*)malloc(sizeof(struct Node));
    new_node->vertex = v;
    new_node->next = NULL;
    return new_node;
}

struct Graph* create_graph(int vertices) {
    struct Graph* graph = (struct Graph*)malloc(sizeof(struct Graph));
    graph->num_vertices = vertices;
    
    for (int i = 0; i < vertices; i++) {
        graph->adj_list[i] = NULL;
    }
    
    return graph;
}

void add_edge(struct Graph* graph, int src, int dest) {
    // Add edge from src to dest
    struct Node* new_node = create_node(dest);
    new_node->next = graph->adj_list[src];
    graph->adj_list[src] = new_node;
    
    // Add edge from dest to src (for undirected graph)
    new_node = create_node(src);
    new_node->next = graph->adj_list[dest];
    graph->adj_list[dest] = new_node;
}

// DFS implementation
void dfs_util(struct Graph* graph, int vertex, int visited[]) {
    visited[vertex] = 1;
    printf("%d ", vertex);
    
    struct Node* adj_list = graph->adj_list[vertex];
    while (adj_list != NULL) {
        int adj_vertex = adj_list->vertex;
        if (!visited[adj_vertex]) {
            dfs_util(graph, adj_vertex, visited);
        }
        adj_list = adj_list->next;
    }
}

void dfs(struct Graph* graph, int start_vertex) {
    int visited[MAX_VERTICES] = {0};
    printf("DFS starting from vertex %d: ", start_vertex);
    dfs_util(graph, start_vertex, visited);
    printf("\n");
}

// BFS implementation
struct Queue {
    int items[MAX_VERTICES];
    int front;
    int rear;
};

void init_queue(struct Queue* q) {
    q->front = -1;
    q->rear = -1;
}

int is_queue_empty(struct Queue* q) {
    return q->front == -1;
}

void enqueue(struct Queue* q, int value) {
    if (q->front == -1) {
        q->front = 0;
    }
    q->rear++;
    q->items[q->rear] = value;
}

int dequeue(struct Queue* q) {
    int item = q->items[q->front];
    q->front++;
    if (q->front > q->rear) {
        q->front = q->rear = -1;
    }
    return item;
}

void bfs(struct Graph* graph, int start_vertex) {
    int visited[MAX_VERTICES] = {0};
    struct Queue q;
    init_queue(&q);
    
    visited[start_vertex] = 1;
    enqueue(&q, start_vertex);
    
    printf("BFS starting from vertex %d: ", start_vertex);
    
    while (!is_queue_empty(&q)) {
        int vertex = dequeue(&q);
        printf("%d ", vertex);
        
        struct Node* temp = graph->adj_list[vertex];
        while (temp != NULL) {
            int adj_vertex = temp->vertex;
            if (!visited[adj_vertex]) {
                visited[adj_vertex] = 1;
                enqueue(&q, adj_vertex);
            }
            temp = temp->next;
        }
    }
    printf("\n");
}

void print_graph(struct Graph* graph) {
    printf("Graph adjacency list:\n");
    for (int i = 0; i < graph->num_vertices; i++) {
        printf("Vertex %d: ", i);
        struct Node* temp = graph->adj_list[i];
        while (temp != NULL) {
            printf("%d -> ", temp->vertex);
            temp = temp->next;
        }
        printf("NULL\n");
    }
}

void free_graph(struct Graph* graph) {
    for (int i = 0; i < graph->num_vertices; i++) {
        struct Node* current = graph->adj_list[i];
        while (current != NULL) {
            struct Node* temp = current;
            current = current->next;
            free(temp);
        }
    }
    free(graph);
}

int main() {
    // Create a sample graph
    struct Graph* graph = create_graph(6);
    
    add_edge(graph, 0, 1);
    add_edge(graph, 0, 2);
    add_edge(graph, 1, 2);
    add_edge(graph, 1, 3);
    add_edge(graph, 2, 3);
    add_edge(graph, 3, 4);
    add_edge(graph, 4, 5);
    
    // Print the graph structure
    print_graph(graph);
    
    // Test DFS
    printf("\n");
    dfs(graph, 0);
    
    // Test BFS
    bfs(graph, 0);
    
    // Cleanup
    free_graph(graph);
    
    return 0;
}
