#include "test.h"

#define V 6

void topological_sort(int graph[V][V]) {
    int in_degree[V];
    for(int i = 0; i < V; i++) {
        in_degree[i] = 0;
    }

    for (int i = 0; i < V; i++) {
        for (int j = 0; j < V; j++) {
            if (graph[i][j] == 1) {
                in_degree[j]++;
            }
        }
    }

    int queue[V];
    int front = 0;
    int rear = 0;

    for (int i = 0; i < V; i++) {
        if (in_degree[i] == 0) {
            queue[rear++] = i;
        }
    }

    int count = 0;
    int result[V];

    while (front != rear) {
        int u = queue[front++];
        result[count] = u;
        count++;

        for (int v = 0; v < V; v++) {
            if (graph[u][v] == 1) {
                in_degree[v]--;
                if (in_degree[v] == 0) {
                    queue[rear++] = v;
                }
            }
        }
    }

    if (count < V) {
        printf("Graph contains a cycle!\n");
    } else {
        printf("Topological Sort: ");
        for (int i = 0; i < V; i++) {
            printf("%d ", result[i]);
        }
        printf("\n");
    }
}

int main() {
    int graph[V][V] = {
        {0, 0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0, 0},
        {0, 0, 0, 1, 0, 0},
        {0, 1, 0, 0, 0, 0},
        {1, 1, 0, 0, 0, 0},
        {1, 0, 1, 0, 0, 0}
    };
    topological_sort(graph);
    return 0;
}
