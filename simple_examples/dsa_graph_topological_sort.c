#include "test.h"

// 拓扑排序算法实现
#define MAX_VERTICES 100

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

void add_edge(struct Graph* graph, int src, int dest) {
    graph->adj[src][dest] = 1;
}

void print_graph(struct Graph* graph) {
    printf("Graph adjacency matrix:\n");
    printf("    ");
    for (int i = 0; i < graph->V; i++) {
        printf("%2d", i);
    }
    printf("\n");
    
    for (int i = 0; i < graph->V; i++) {
        printf("%2d: ", i);
        for (int j = 0; j < graph->V; j++) {
            printf("%2d", graph->adj[i][j]);
        }
        printf("\n");
    }
    printf("\n");
}

// Recursive function used by topological_sort
void topological_sort_util(struct Graph* graph, int v,
                         int visited[], int* stack, int* stack_index) {
    visited[v] = 1;
    
    printf("Visiting vertex %d\n", v);
    
    // Recur for all adjacent vertices
    for (int i = 0; i < graph->V; i++) {
        if (graph->adj[v][i] && !visited[i]) {
            printf("Following edge %d -> %d\n", v, i);
            topological_sort_util(graph, i, visited, stack, stack_index);
        }
    }
    
    // Push current vertex to stack
    stack[(*stack_index)++] = v;
    printf("Adding %d to result\n", v);
}

void topological_sort(struct Graph* graph) {
    int visited[MAX_VERTICES] = {0};
    int stack[MAX_VERTICES];
    int stack_index = 0;
    
    printf("Starting topological sort:\n\n");
    
    // Call the recursive helper function for all vertices
    for (int i = 0; i < graph->V; i++) {
        if (!visited[i]) {
            topological_sort_util(graph, i, visited, stack, &stack_index);
        }
    }
    
    // Print contents of stack in reverse order
    printf("\nTopological sort result: ");
    for (int i = stack_index - 1; i >= 0; i--) {
        printf("%d ", stack[i]);
    }
    printf("\n");
}

// Function to check if graph has cycle using DFS
int has_cycle_util(struct Graph* graph, int v,
                  int visited[], int rec_stack[]) {
    if (!visited[v]) {
        visited[v] = 1;
        rec_stack[v] = 1;
        
        for (int i = 0; i < graph->V; i++) {
            if (graph->adj[v][i]) {
                if (!visited[i] && has_cycle_util(graph, i, visited, rec_stack))
                    return 1;
                else if (rec_stack[i])
                    return 1;
            }
        }
    }
    rec_stack[v] = 0;
    return 0;
}

int has_cycle(struct Graph* graph) {
    int visited[MAX_VERTICES] = {0};
    int rec_stack[MAX_VERTICES] = {0};
    
    for (int i = 0; i < graph->V; i++) {
        if (has_cycle_util(graph, i, visited, rec_stack))
            return 1;
    }
    return 0;
}

// Test cases
void test_basic_dag() {
    printf("Testing basic DAG:\n");
    struct Graph* graph = create_graph(6);
    
    add_edge(graph, 5, 2);
    add_edge(graph, 5, 0);
    add_edge(graph, 4, 0);
    add_edge(graph, 4, 1);
    add_edge(graph, 2, 3);
    add_edge(graph, 3, 1);
    
    print_graph(graph);
    
    if (has_cycle(graph)) {
        printf("Graph has cycle. Topological sort not possible.\n");
    } else {
        topological_sort(graph);
    }
    printf("\n");
    
    free(graph);
}

void test_linear_graph() {
    printf("Testing linear graph:\n");
    struct Graph* graph = create_graph(4);
    
    add_edge(graph, 0, 1);
    add_edge(graph, 1, 2);
    add_edge(graph, 2, 3);
    
    print_graph(graph);
    
    if (has_cycle(graph)) {
        printf("Graph has cycle. Topological sort not possible.\n");
    } else {
        topological_sort(graph);
    }
    printf("\n");
    
    free(graph);
}

void test_cyclic_graph() {
    printf("Testing cyclic graph:\n");
    struct Graph* graph = create_graph(4);
    
    add_edge(graph, 0, 1);
    add_edge(graph, 1, 2);
    add_edge(graph, 2, 3);
    add_edge(graph, 3, 0);  // Creates a cycle
    
    print_graph(graph);
    
    if (has_cycle(graph)) {
        printf("Graph has cycle. Topological sort not possible.\n");
    } else {
        topological_sort(graph);
    }
    printf("\n");
    
    free(graph);
}

void test_disconnected_dag() {
    printf("Testing disconnected DAG:\n");
    struct Graph* graph = create_graph(7);
    
    // First component
    add_edge(graph, 0, 1);
    add_edge(graph, 1, 2);
    
    // Second component
    add_edge(graph, 3, 4);
    add_edge(graph, 4, 5);
    add_edge(graph, 4, 6);
    
    print_graph(graph);
    
    if (has_cycle(graph)) {
        printf("Graph has cycle. Topological sort not possible.\n");
    } else {
        topological_sort(graph);
    }
    printf("\n");
    
    free(graph);
}

void test_single_vertex() {
    printf("Testing single vertex graph:\n");
    struct Graph* graph = create_graph(1);
    
    print_graph(graph);
    
    if (has_cycle(graph)) {
        printf("Graph has cycle. Topological sort not possible.\n");
    } else {
        topological_sort(graph);
    }
    printf("\n");
    
    free(graph);
}

int main() {
    test_basic_dag();
    test_linear_graph();
    test_cyclic_graph();
    test_disconnected_dag();
    test_single_vertex();
    
    return 0;
}
