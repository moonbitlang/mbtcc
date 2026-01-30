#include "test.h"

// 链表实现
struct ListNode {
    int val;
    struct ListNode* next;
};

struct ListNode* create_node(int value) {
    struct ListNode* node = (struct ListNode*)malloc(sizeof(struct ListNode));
    node->val = value;
    node->next = NULL;
    return node;
}

void insert_front(struct ListNode** head, int value) {
    struct ListNode* new_node = create_node(value);
    new_node->next = *head;
    *head = new_node;
}

void insert_back(struct ListNode** head, int value) {
    struct ListNode* new_node = create_node(value);
    if (*head == NULL) {
        *head = new_node;
        return;
    }
    
    struct ListNode* current = *head;
    while (current->next != NULL) {
        current = current->next;
    }
    current->next = new_node;
}

void delete_node(struct ListNode** head, int value) {
    if (*head == NULL) return;
    
    if ((*head)->val == value) {
        struct ListNode* temp = *head;
        *head = (*head)->next;
        free(temp);
        return;
    }
    
    struct ListNode* current = *head;
    while (current->next != NULL && current->next->val != value) {
        current = current->next;
    }
    
    if (current->next != NULL) {
        struct ListNode* temp = current->next;
        current->next = temp->next;
        free(temp);
    }
}

void print_list(struct ListNode* head) {
    printf("List: ");
    struct ListNode* current = head;
    while (current != NULL) {
        printf("%d ", current->val);
        current = current->next;
    }
    printf("\n");
}

void free_list(struct ListNode* head) {
    struct ListNode* current = head;
    while (current != NULL) {
        struct ListNode* temp = current;
        current = current->next;
        free(temp);
    }
}

int main() {
    struct ListNode* head = NULL;
    
    // Test insertions
    printf("Testing insertions:\n");
    insert_back(&head, 1);
    insert_back(&head, 2);
    insert_back(&head, 3);
    print_list(head);
    
    insert_front(&head, 0);
    print_list(head);
    
    // Test deletion
    printf("\nTesting deletions:\n");
    delete_node(&head, 2);
    print_list(head);
    
    delete_node(&head, 0);
    print_list(head);
    
    // Cleanup
    free_list(head);
    
    return 0;
}
