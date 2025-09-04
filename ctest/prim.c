#include "test.h"

#define V 5
#define INF 99999

int main() {
    int no_edge;
    int selected[V];
    for (int i = 0; i < V; i++) {
        selected[i] = 0;
    }

    no_edge = 0;
    selected[0] = 1;

    int x;
    int y;

    int G[V][V] = {
        {0, 9, 75, 0, 0},
        {9, 0, 95, 19, 42},
        {75, 95, 0, 51, 66},
        {0, 19, 51, 0, 31},
        {0, 42, 66, 31, 0}
    };

    printf("Edge : Weight\n");
    int total_weight = 0;

    while (no_edge < V - 1) {
        int min = INF;
        x = 0;
        y = 0;

        for (int i = 0; i < V; i++) {
            if (selected[i]) {
                for (int j = 0; j < V; j++) {
                    if (!selected[j] && G[i][j]) {
                        if (min > G[i][j]) {
                            min = G[i][j];
                            x = i;
                            y = j;
                        }
                    }
                }
            }
        }
        printf("%d - %d : %d\n", x, y, G[x][y]);
        total_weight = total_weight + G[x][y];
        selected[y] = 1;
        no_edge++;
    }
    printf("Total weight: %d\n", total_weight);

    return 0;
}
