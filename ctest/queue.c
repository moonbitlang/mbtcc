#include "test.h"

#define MAX_SIZE 5

typedef struct {
    int data[MAX_SIZE];
    int front;
    int rear;
    int size;
} Queue;

void initQueue(Queue* q) {
    q->front = 0;
    q->rear = -1;
    q->size = 0;
}

int isFull(Queue* q) {
    return q->size == MAX_SIZE;
}

int isEmpty(Queue* q) {
    return q->size == 0;
}

void enqueue(Queue* q, int item) {
    if (isFull(q)) {
        printf("Queue is full! Cannot enqueue %d\n", item);
        return;
    }
    q->rear = (q->rear + 1) % MAX_SIZE;
    q->data[q->rear] = item;
    q->size++;
    printf("Enqueued: %d\n", item);
}

int dequeue(Queue* q) {
    if (isEmpty(q)) {
        printf("Queue is empty! Cannot dequeue.\n");
        return -1; // Indicate error
    }
    int item = q->data[q->front];
    q->front = (q->front + 1) % MAX_SIZE;
    q->size--;
    printf("Dequeued: %d\n", item);
    return item;
}

int peek(Queue* q) {
    if (isEmpty(q)) {
        printf("Queue is empty! No peek value.\n");
        return -1;
    }
    return q->data[q->front];
}

int main() {
    Queue q;
    initQueue(&q);

    enqueue(&q, 10);
    enqueue(&q, 20);
    enqueue(&q, 30);
    printf("Peek: %d\n", peek(&q));
    dequeue(&q);
    enqueue(&q, 40);
    enqueue(&q, 50);
    enqueue(&q, 60); // Should fail

    dequeue(&q);
    dequeue(&q);
    dequeue(&q);
    dequeue(&q);
    dequeue(&q); // Should fail

    return 0;
}
