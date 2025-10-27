#include "test.h"

// 测试复杂的switch和循环组合
enum State {
    INIT,
    RUNNING,
    PAUSED,
    ERROR,
    FINISHED
};

void process_state(enum State state, int* counter) {
    switch (state) {
        case INIT:
            printf("Initializing system\n");
            *counter = 0;
            break;
            
        case RUNNING:
            printf("System is running\n");
            while (*counter < 3) {
                printf("Processing step %d\n", *counter + 1);
                (*counter)++;
            }
            break;
            
        case PAUSED:
            printf("System is paused\n");
            if (*counter > 0) {
                printf("Current progress: %d steps\n", *counter);
            }
            break;
            
        case ERROR:
            printf("Error state\n");
            do {
                printf("Attempting recovery: step %d\n", *counter);
                (*counter)--;
            } while (*counter > 0);
            break;
            
        case FINISHED:
            printf("Process finished\n");
            break;
            
        default:
            printf("Unknown state\n");
    }
}

int main() {
    int counter = 0;
    enum State states[] = {INIT, RUNNING, PAUSED, RUNNING, ERROR, FINISHED};
    int num_states = 6;
    
    for (int i = 0; i < num_states; i++) {
        printf("\nState transition %d:\n", i + 1);
        process_state(states[i], &counter);
    }
    
    return 0;
}
