#include "test.h"

// 栈实现
#define MAX_SIZE 100

struct Stack {
    int items[MAX_SIZE];
    int top;
};

void init_stack(struct Stack* stack) {
    stack->top = -1;
}

int is_empty(struct Stack* stack) {
    return stack->top == -1;
}

int is_full(struct Stack* stack) {
    return stack->top == MAX_SIZE - 1;
}

void push(struct Stack* stack, int value) {
    if (is_full(stack)) {
        printf("Stack overflow\n");
        return;
    }
    stack->items[++stack->top] = value;
}

int pop(struct Stack* stack) {
    if (is_empty(stack)) {
        printf("Stack underflow\n");
        return -1;
    }
    return stack->items[stack->top--];
}

int peek(struct Stack* stack) {
    if (is_empty(stack)) {
        printf("Stack is empty\n");
        return -1;
    }
    return stack->items[stack->top];
}

void print_stack(struct Stack* stack) {
    printf("Stack: ");
    for (int i = 0; i <= stack->top; i++) {
        printf("%d ", stack->items[i]);
    }
    printf("\n");
}

// Test stack operations
void test_stack_operations() {
    struct Stack stack;
    init_stack(&stack);
    
    printf("Testing push operations:\n");
    push(&stack, 1);
    push(&stack, 2);
    push(&stack, 3);
    print_stack(&stack);
    
    printf("\nTesting peek operation:\n");
    printf("Top element: %d\n", peek(&stack));
    
    printf("\nTesting pop operations:\n");
    printf("Popped: %d\n", pop(&stack));
    print_stack(&stack);
    
    printf("Popped: %d\n", pop(&stack));
    print_stack(&stack);
}

// Test stack applications
void test_stack_applications() {
    struct Stack stack;
    init_stack(&stack);
    
    // Reverse a sequence of numbers
    printf("\nTesting number sequence reversal:\n");
    printf("Original sequence: 1 2 3 4 5\n");
    
    for (int i = 1; i <= 5; i++) {
        push(&stack, i);
    }
    
    printf("Reversed sequence: ");
    while (!is_empty(&stack)) {
        printf("%d ", pop(&stack));
    }
    printf("\n");
    
    // Check balanced parentheses
    printf("\nTesting balanced parentheses:\n");
    char* expr = "((()))()";
    printf("Expression: %s\n", expr);
    
    int is_balanced = 1;
    for (int i = 0; expr[i] != '\0'; i++) {
        if (expr[i] == '(') {
            push(&stack, 1);
        } else if (expr[i] == ')') {
            if (is_empty(&stack)) {
                is_balanced = 0;
                break;
            }
            pop(&stack);
        }
    }
    
    if (!is_empty(&stack)) {
        is_balanced = 0;
    }
    
    printf("Is balanced: %s\n", is_balanced ? "Yes" : "No");
}

int main() {
    test_stack_operations();
    test_stack_applications();
    return 0;
}
