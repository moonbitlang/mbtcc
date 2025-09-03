#include "test.h"

#define NULL 0
#define MAX_SIZE 100

struct Stack {
    int top;
    unsigned capacity;
    int* array;
};

struct Stack* createStack(unsigned capacity) {
    struct Stack* stack = (struct Stack*) malloc(sizeof(struct Stack));
    stack->capacity = capacity;
    stack->top = -1;
    stack->array = (int*) malloc(stack->capacity * sizeof(int));
    return stack;
}

int isFull(struct Stack* stack) {
    return stack->top == stack->capacity - 1;
}

int isEmpty(struct Stack* stack) {
    return stack->top == -1;
}

void push(struct Stack* stack, int item) {
    if (isFull(stack)) {
        printf("Stack overflow\n");
        return;
    }
    stack->array[++stack->top] = item;
    printf("%d pushed to stack\n", item);
}

int pop(struct Stack* stack) {
    if (isEmpty(stack)) {
        printf("Stack underflow\n");
        return -1; // Return a sentinel value for error
    }
    return stack->array[stack->top--];
}

int peek(struct Stack* stack) {
    if (isEmpty(stack)) {
        return -1; // Return a sentinel value for error
    }
    return stack->array[stack->top];
}

int main() {
    struct Stack* stack = createStack(MAX_SIZE);

    push(stack, 10);
    push(stack, 20);
    push(stack, 30);

    printf("%d popped from stack\n", pop(stack));
    printf("Top element is %d\n", peek(stack));
    printf("%d popped from stack\n", pop(stack));

    push(stack, 40);
    printf("Top element is %d\n", peek(stack));
    
    free(stack->array);
    free(stack);

    return 0;
}
