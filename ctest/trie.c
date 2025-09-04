#include "test.h"

#define ALPHABET_SIZE 26
#define NULL 0

struct TrieNode {
    struct TrieNode *children[ALPHABET_SIZE];
    int isEndOfWord;
};

struct TrieNode *getNode() {
    struct TrieNode *pNode = (struct TrieNode *)malloc(sizeof(struct TrieNode));
    pNode->isEndOfWord = 0;
    for (int i = 0; i < ALPHABET_SIZE; i++) {
        pNode->children[i] = NULL;
    }
    return pNode;
}

void insert(struct TrieNode *root, const char *key) {
    struct TrieNode *pCrawl = root;
    int len = 0;
    while(key[len] != '\0') len++;

    for (int level = 0; level < len; level++) {
        int index = key[level] - 'a';
        if (!pCrawl->children[index]) {
            pCrawl->children[index] = getNode();
        }
        pCrawl = pCrawl->children[index];
    }
    pCrawl->isEndOfWord = 1;
}

int search(struct TrieNode *root, const char *key) {
    struct TrieNode *pCrawl = root;
    int len = 0;
    while(key[len] != '\0') len++;

    for (int level = 0; level < len; level++) {
        int index = key[level] - 'a';
        if (!pCrawl->children[index]) {
            return 0;
        }
        pCrawl = pCrawl->children[index];
    }
    return pCrawl != NULL && pCrawl->isEndOfWord;
}

void freeTrie(struct TrieNode* node) {
    if (node == NULL) return;
    for (int i = 0; i < ALPHABET_SIZE; i++) {
        freeTrie(node->children[i]);
    }
    free(node);
}


int main() {
    char keys[][8] = {"the", "a", "there", "answer", "any", "by", "bye", "their"};
    int n = 8;

    struct TrieNode *root = getNode();

    for (int i = 0; i < n; i++) {
        insert(root, keys[i]);
    }

    printf("'the' --- %d\n", search(root, "the"));
    printf("'these' --- %d\n", search(root, "these"));
    printf("'their' --- %d\n", search(root, "their"));
    printf("'thaw' --- %d\n", search(root, "thaw"));

    freeTrie(root);

    return 0;
}
