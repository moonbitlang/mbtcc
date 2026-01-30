#include "test.h"

// 复合数据结构 5: 简单的指令集模拟 (Instruction Set)
// 数组包含 Tagged Union

typedef enum { OP_PUSH, OP_ADD, OP_PRINT } OpCode;

struct Instruction {
    OpCode code;
    union {
        int operand; // For PUSH
        // ADD, PRINT needs no operand
    } args;
};

#define MAX_STACK 100
int stack[MAX_STACK];
int sp = 0;

void push(int v) {
    if (sp < MAX_STACK) stack[sp++] = v;
}

int pop() {
    if (sp > 0) return stack[--sp];
    return 0;
}

int main() {
    struct Instruction program[] = {
        { OP_PUSH, { .operand = 10 } },
        { OP_PUSH, { .operand = 20 } },
        { OP_ADD,  { 0 } },
        { OP_PRINT, { 0 } }
    };
    
    int pc = 0;
    int prog_size = 4;
    
    while (pc < prog_size) {
        struct Instruction* inst = &program[pc];
        switch (inst->code) {
            case OP_PUSH:
                push(inst->args.operand);
                break;
            case OP_ADD: {
                int a = pop();
                int b = pop();
                push(a + b);
                break;
            }
            case OP_PRINT:
                printf("Top of stack: %d\n", pop());
                break;
        }
        pc++;
    }
    
    return 0;
}
