#include "test.h"

// 哈希表实现
#define TABLE_SIZE 10

struct KeyValue {
    int key;
    int value;
    int is_occupied;
};

struct HashTable {
    struct KeyValue table[TABLE_SIZE];
    int size;
};

void init_table(struct HashTable* ht) {
    for (int i = 0; i < TABLE_SIZE; i++) {
        ht->table[i].is_occupied = 0;
    }
    ht->size = 0;
}

int hash_function(int key) {
    return key % TABLE_SIZE;
}

// Linear probing for collision resolution
int probe(struct HashTable* ht, int key) {
    int index = hash_function(key);
    int i = 0;
    
    while (ht->table[(index + i) % TABLE_SIZE].is_occupied &&
           ht->table[(index + i) % TABLE_SIZE].key != key) {
        i++;
        if (i == TABLE_SIZE) return -1;  // Table is full
    }
    
    return (index + i) % TABLE_SIZE;
}

void insert(struct HashTable* ht, int key, int value) {
    if (ht->size == TABLE_SIZE) {
        printf("Hash table is full\n");
        return;
    }
    
    int index = probe(ht, key);
    if (index == -1) {
        printf("Failed to insert\n");
        return;
    }
    
    if (!ht->table[index].is_occupied) {
        ht->size++;
    }
    
    ht->table[index].key = key;
    ht->table[index].value = value;
    ht->table[index].is_occupied = 1;
}

int search(struct HashTable* ht, int key) {
    int index = hash_function(key);
    int i = 0;
    
    while (ht->table[(index + i) % TABLE_SIZE].is_occupied) {
        if (ht->table[(index + i) % TABLE_SIZE].key == key) {
            return ht->table[(index + i) % TABLE_SIZE].value;
        }
        i++;
        if (i == TABLE_SIZE) break;
    }
    
    return -1;  // Key not found
}

void delete(struct HashTable* ht, int key) {
    int index = hash_function(key);
    int i = 0;
    
    while (ht->table[(index + i) % TABLE_SIZE].is_occupied) {
        if (ht->table[(index + i) % TABLE_SIZE].key == key) {
            ht->table[(index + i) % TABLE_SIZE].is_occupied = 0;
            ht->size--;
            printf("Key %d deleted\n", key);
            return;
        }
        i++;
        if (i == TABLE_SIZE) break;
    }
    
    printf("Key %d not found\n", key);
}

void print_table(struct HashTable* ht) {
    printf("Hash Table Contents:\n");
    for (int i = 0; i < TABLE_SIZE; i++) {
        if (ht->table[i].is_occupied) {
            printf("Index %d: Key = %d, Value = %d\n",
                   i, ht->table[i].key, ht->table[i].value);
        }
    }
    printf("Table size: %d\n", ht->size);
}

int main() {
    struct HashTable ht;
    init_table(&ht);
    
    // Test insertion
    printf("Inserting key-value pairs:\n");
    insert(&ht, 5, 50);
    insert(&ht, 15, 150);
    insert(&ht, 25, 250);
    insert(&ht, 35, 350);
    print_table(&ht);
    
    // Test search
    printf("\nSearching for keys:\n");
    int key = 15;
    int value = search(&ht, key);
    printf("Value for key %d: %d\n", key, value);
    
    key = 100;
    value = search(&ht, key);
    printf("Value for key %d: %d\n", key, value);
    
    // Test deletion
    printf("\nDeleting keys:\n");
    delete(&ht, 15);
    delete(&ht, 100);
    
    printf("\nFinal hash table state:\n");
    print_table(&ht);
    
    return 0;
}
