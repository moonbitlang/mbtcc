
#include "test.h"

#define NULL 0

typedef struct Node {
  int data;
  struct Node* next;
} Node;

Node* create_node(int data) {
  Node* new_node = (Node*)malloc(sizeof(Node));
  new_node->data = data;
  new_node->next = NULL;
  return new_node;
}

void append(Node** head_ref, int new_data) {
  Node* new_node = create_node(new_data);
  if (*head_ref == NULL) {
    *head_ref = new_node;
    return;
  }
  Node* last = *head_ref;
  while (last->next != NULL) {
    last = last->next;
  }
  last->next = new_node;
}

void delete_list(Node** head_ref) {
  Node* current = *head_ref;
  Node* next;
  while (current != NULL) {
    next = current->next;
    free(current);
    current = next;
  }
  *head_ref = NULL;
}

void sum_list(Node* head, int* sum) {
  *sum = NULL;
  Node* current = head;
  while (current != NULL) {
    *sum += current->data;
    current = current->next;
  }
}

int main() {
  Node* head = NULL;
  append(&head, 1);
  append(&head, 2);
  append(&head, 3);

  int sum = 0;
  sum_list(head, &sum);
  printf("Sum of linked list: %d\n", sum); // Expected output: 6

  delete_list(&head);
  return 0;
}

