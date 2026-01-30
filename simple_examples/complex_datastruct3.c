#include "test.h"

// 复合数据结构 3: 简单的表达式树 (AST)

typedef enum { EXPR_LITERAL, EXPR_ADD, EXPR_SUB } ExprType;

struct Expr; // Forward declaration

struct BinaryOp {
    struct Expr* left;
    struct Expr* right;
};

struct Expr {
    ExprType type;
    union {
        int value; // For LITERAL
        struct BinaryOp bin; // For ADD, SUB
    } as;
};

struct Expr* make_literal(int val) {
    struct Expr* e = (struct Expr*)malloc(sizeof(struct Expr));
    e->type = EXPR_LITERAL;
    e->as.value = val;
    return e;
}

struct Expr* make_op(ExprType type, struct Expr* l, struct Expr* r) {
    struct Expr* e = (struct Expr*)malloc(sizeof(struct Expr));
    e->type = type;
    e->as.bin.left = l;
    e->as.bin.right = r;
    return e;
}

int eval(struct Expr* e) {
    switch (e->type) {
        case EXPR_LITERAL:
            return e->as.value;
        case EXPR_ADD:
            return eval(e->as.bin.left) + eval(e->as.bin.right);
        case EXPR_SUB:
            return eval(e->as.bin.left) - eval(e->as.bin.right);
    }
    return 0;
}

int main() {
    // (10 + 5) - 3
    struct Expr* ten = make_literal(10);
    struct Expr* five = make_literal(5);
    struct Expr* three = make_literal(3);
    
    struct Expr* add = make_op(EXPR_ADD, ten, five);
    struct Expr* root = make_op(EXPR_SUB, add, three);
    
    printf("Result: %d\n", eval(root));
    
    return 0;
}
