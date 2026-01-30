#include "test.h"

// 测试复杂的结构体数组和指针
struct Node {
    int value;
    struct Node* next;
};

struct List {
    struct Node* head;
    int size;
};

struct Matrix {
    int rows;
    int cols;
    int** data;
};

void init_list(struct List* list) {
    list->head = NULL;
    list->size = 0;
}

void add_to_list(struct List* list, int value) {
    struct Node* new_node = (struct Node*)malloc(sizeof(struct Node));
    new_node->value = value;
    new_node->next = list->head;
    list->head = new_node;
    list->size++;
}

void print_list(struct List* list) {
    struct Node* current = list->head;
    printf("List (size %d): ", list->size);
    while (current != NULL) {
        printf("%d ", current->value);
        current = current->next;
    }
    printf("\n");
}

void free_list(struct List* list) {
    struct Node* current = list->head;
    while (current != NULL) {
        struct Node* next = current->next;
        free(current);
        current = next;
    }
    list->head = NULL;
    list->size = 0;
}

struct Matrix* create_matrix(int rows, int cols) {
    struct Matrix* matrix = (struct Matrix*)malloc(sizeof(struct Matrix));
    matrix->rows = rows;
    matrix->cols = cols;
    
    matrix->data = (int**)malloc(rows * sizeof(int*));
    for (int i = 0; i < rows; i++) {
        matrix->data[i] = (int*)malloc(cols * sizeof(int));
    }
    
    return matrix;
}

void init_matrix(struct Matrix* matrix) {
    for (int i = 0; i < matrix->rows; i++) {
        for (int j = 0; j < matrix->cols; j++) {
            matrix->data[i][j] = i * matrix->cols + j;
        }
    }
}

void print_matrix(struct Matrix* matrix) {
    printf("Matrix %dx%d:\n", matrix->rows, matrix->cols);
    for (int i = 0; i < matrix->rows; i++) {
        for (int j = 0; j < matrix->cols; j++) {
            printf("%3d ", matrix->data[i][j]);
        }
        printf("\n");
    }
}

void free_matrix(struct Matrix* matrix) {
    for (int i = 0; i < matrix->rows; i++) {
        free(matrix->data[i]);
    }
    free(matrix->data);
    free(matrix);
}

int main() {
    // Test linked list
    struct List list;
    init_list(&list);
    
    for (int i = 1; i <= 5; i++) {
        add_to_list(&list, i * 10);
    }
    print_list(&list);
    
    // Test matrix
    struct Matrix* matrix = create_matrix(3, 4);
    init_matrix(matrix);
    print_matrix(matrix);
    
    // Cleanup
    free_list(&list);
    free_matrix(matrix);
    
    return 0;
}
