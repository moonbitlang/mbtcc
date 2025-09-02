#include "test.h"

#define TABLE_SIZE 10

struct Node {
    int key;
    int value;
    struct Node* next;
};

struct Node* table[TABLE_SIZE];

// Hash function
int hashCode(int key) {
    return key % TABLE_SIZE;
}

// Insert a key-value pair
void insert(int key, int value) {
    int hashIndex = hashCode(key);
    struct Node* newNode = (struct Node*)malloc(sizeof(struct Node));
    newNode->key = key;
    newNode->value = value;
    newNode->next = (void*)0;

    if (table[hashIndex] == (void*)0) {
        table[hashIndex] = newNode;
    } else {
        // Collision: add to the beginning of the list
        newNode->next = table[hashIndex];
        table[hashIndex] = newNode;
    }
}

// Search for a key and return its value
int search(int key) {
    int hashIndex = hashCode(key);
    struct Node* current = table[hashIndex];
    while (current != (void*)0) {
        if (current->key == key) {
            return current->value;
        }
        current = current->next;
    }
    return -1; // Not found
}

int main() {
    for (int i = 0; i < TABLE_SIZE; i++) {
        table[i] = (void*)0;
    }

    insert(1, 10);
    insert(2, 20);
    insert(12, 30); // Collision with 2
    insert(5, 50);

    printf("Value for key 1: %d\n", search(1));
    printf("Value for key 12: %d\n", search(12));
    printf("Value for key 5: %d\n", search(5));
    printf("Value for key 99: %d\n", search(99));

    return 0;
}
