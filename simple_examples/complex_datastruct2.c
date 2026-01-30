#include "test.h"

// 复合数据结构 2: 异构链表 (Linked List of Tagged Unions)

typedef enum { KIND_NUM, KIND_MSG } NodeKind;

struct Node {
    NodeKind kind;
    union {
        int num;
        char* msg;
    } content;
    struct Node* next;
};

struct Node* create_num_node(int n) {
    struct Node* node = (struct Node*)malloc(sizeof(struct Node));
    node->kind = KIND_NUM;
    node->content.num = n;
    node->next = NULL;
    return node;
}

struct Node* create_msg_node(char* s) {
    struct Node* node = (struct Node*)malloc(sizeof(struct Node));
    node->kind = KIND_MSG;
    node->content.msg = s;
    node->next = NULL;
    return node;
}

int main() {
    struct Node* head = create_num_node(1);
    head->next = create_msg_node("second");
    head->next->next = create_num_node(3);
    
    struct Node* curr = head;
    while (curr) {
        if (curr->kind == KIND_NUM) {
            printf("Node(Num): %d\n", curr->content.num);
        } else {
            printf("Node(Msg): %s\n", curr->content.msg);
        }
        curr = curr->next;
    }
    
    // Cleanup skipped for brevity in simple test
    return 0;
}

