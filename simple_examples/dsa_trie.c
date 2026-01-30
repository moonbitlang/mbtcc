#include "test.h"

// 字典树实现
#define ALPHABET_SIZE 26

struct TrieNode {
    struct TrieNode* children[ALPHABET_SIZE];
    int is_end_of_word;
};

struct TrieNode* create_node() {
    struct TrieNode* node = (struct TrieNode*)malloc(sizeof(struct TrieNode));
    
    for (int i = 0; i < ALPHABET_SIZE; i++) {
        node->children[i] = NULL;
    }
    
    node->is_end_of_word = 0;
    return node;
}

void insert(struct TrieNode* root, const char* word) {
    int length = strlen(word);
    struct TrieNode* current = root;
    
    for (int i = 0; i < length; i++) {
        int index = word[i] - 'a';
        if (current->children[index] == NULL) {
            current->children[index] = create_node();
        }
        current = current->children[index];
    }
    
    current->is_end_of_word = 1;
}

int search(struct TrieNode* root, const char* word) {
    int length = strlen(word);
    struct TrieNode* current = root;
    
    for (int i = 0; i < length; i++) {
        int index = word[i] - 'a';
        if (current->children[index] == NULL) {
            return 0;
        }
        current = current->children[index];
    }
    
    return current->is_end_of_word;
}

int starts_with(struct TrieNode* root, const char* prefix) {
    int length = strlen(prefix);
    struct TrieNode* current = root;
    
    for (int i = 0; i < length; i++) {
        int index = prefix[i] - 'a';
        if (current->children[index] == NULL) {
            return 0;
        }
        current = current->children[index];
    }
    
    return 1;
}

void free_trie(struct TrieNode* node) {
    if (node == NULL) {
        return;
    }
    
    for (int i = 0; i < ALPHABET_SIZE; i++) {
        free_trie(node->children[i]);
    }
    
    free(node);
}

// Print all words in trie
void print_words_util(struct TrieNode* node, char* prefix, int length) {
    if (node->is_end_of_word) {
        prefix[length] = '\0';
        printf("%s\n", prefix);
    }
    
    for (int i = 0; i < ALPHABET_SIZE; i++) {
        if (node->children[i]) {
            prefix[length] = i + 'a';
            print_words_util(node->children[i], prefix, length + 1);
        }
    }
}

void print_words(struct TrieNode* root) {
    char prefix[100];  // Assuming max word length is 100
    printf("Words in trie:\n");
    print_words_util(root, prefix, 0);
}

int main() {
    struct TrieNode* root = create_node();
    
    // Insert some words
    insert(root, "hello");
    insert(root, "world");
    insert(root, "help");
    insert(root, "word");
    insert(root, "hell");
    
    // Print all words
    print_words(root);
    
    // Test search
    printf("\nSearch results:\n");
    printf("Searching 'hello': %s\n", search(root, "hello") ? "Found" : "Not found");
    printf("Searching 'help': %s\n", search(root, "help") ? "Found" : "Not found");
    printf("Searching 'helper': %s\n", search(root, "helper") ? "Found" : "Not found");
    
    // Test prefix search
    printf("\nPrefix search results:\n");
    printf("Prefix 'hel': %s\n", starts_with(root, "hel") ? "Found" : "Not found");
    printf("Prefix 'wor': %s\n", starts_with(root, "wor") ? "Found" : "Not found");
    printf("Prefix 'cat': %s\n", starts_with(root, "cat") ? "Found" : "Not found");
    
    // Cleanup
    free_trie(root);
    
    return 0;
}
