#include "test.h"

// 队列实现
#define MAX_SIZE 100

struct Queue {
    int items[MAX_SIZE];
    int front;
    int rear;
    int size;
};

void init_queue(struct Queue* queue) {
    queue->front = 0;
    queue->rear = -1;
    queue->size = 0;
}

int is_empty(struct Queue* queue) {
    return queue->size == 0;
}

int is_full(struct Queue* queue) {
    return queue->size == MAX_SIZE;
}

void enqueue(struct Queue* queue, int value) {
    if (is_full(queue)) {
        printf("Queue overflow\n");
        return;
    }
    
    queue->rear = (queue->rear + 1) % MAX_SIZE;
    queue->items[queue->rear] = value;
    queue->size++;
}

int dequeue(struct Queue* queue) {
    if (is_empty(queue)) {
        printf("Queue underflow\n");
        return -1;
    }
    
    int value = queue->items[queue->front];
    queue->front = (queue->front + 1) % MAX_SIZE;
    queue->size--;
    return value;
}

int front(struct Queue* queue) {
    if (is_empty(queue)) {
        printf("Queue is empty\n");
        return -1;
    }
    return queue->items[queue->front];
}

void print_queue(struct Queue* queue) {
    if (is_empty(queue)) {
        printf("Queue is empty\n");
        return;
    }
    
    printf("Queue: ");
    int count = 0;
    int index = queue->front;
    
    while (count < queue->size) {
        printf("%d ", queue->items[index]);
        index = (index + 1) % MAX_SIZE;
        count++;
    }
    printf("\n");
}

// Test basic queue operations
void test_queue_operations() {
    struct Queue queue;
    init_queue(&queue);
    
    printf("Testing enqueue operations:\n");
    enqueue(&queue, 1);
    enqueue(&queue, 2);
    enqueue(&queue, 3);
    print_queue(&queue);
    
    printf("\nTesting front operation:\n");
    printf("Front element: %d\n", front(&queue));
    
    printf("\nTesting dequeue operations:\n");
    printf("Dequeued: %d\n", dequeue(&queue));
    print_queue(&queue);
    
    printf("Dequeued: %d\n", dequeue(&queue));
    print_queue(&queue);
}

// Test circular queue behavior
void test_circular_queue() {
    struct Queue queue;
    init_queue(&queue);
    
    printf("\nTesting circular queue behavior:\n");
    
    // Fill the queue
    for (int i = 1; i <= 5; i++) {
        enqueue(&queue, i);
    }
    print_queue(&queue);
    
    // Remove some elements
    printf("\nRemoving two elements:\n");
    dequeue(&queue);
    dequeue(&queue);
    print_queue(&queue);
    
    // Add more elements to demonstrate circular behavior
    printf("\nAdding new elements:\n");
    enqueue(&queue, 6);
    enqueue(&queue, 7);
    print_queue(&queue);
}

// Test queue applications
void test_queue_applications() {
    struct Queue queue;
    init_queue(&queue);
    
    printf("\nSimulating a print queue:\n");
    printf("Adding print jobs...\n");
    
    // Add print jobs
    for (int i = 1; i <= 3; i++) {
        printf("Adding job %d to queue\n", i);
        enqueue(&queue, i);
        print_queue(&queue);
    }
    
    // Process print jobs
    printf("\nProcessing print jobs...\n");
    while (!is_empty(&queue)) {
        int job = dequeue(&queue);
        printf("Processing job %d\n", job);
        print_queue(&queue);
    }
}

int main() {
    test_queue_operations();
    test_circular_queue();
    test_queue_applications();
    return 0;
}
