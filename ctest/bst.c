#include "test.h"

struct Node {
    int key;
    struct Node *left, *right;
};

// A utility function to create a new BST node
struct Node* newNode(int item) {
    struct Node* temp = (struct Node*)malloc(sizeof(struct Node));
    temp->key = item;
    temp->left = temp->right = (void*)0;
    return temp;
}

// A utility function to do inorder traversal of BST
void inorder(struct Node* root) {
    if (root != (void*)0) {
        inorder(root->left);
        printf("%d ", root->key);
        inorder(root->right);
    }
}

/* A utility function to insert a new node with given key in BST */
struct Node* insert(struct Node* node, int key) {
    /* If the tree is empty, return a new node */
    if (node == (void*)0) return newNode(key);

    /* Otherwise, recur down the tree */
    if (key < node->key)
        node->left = insert(node->left, key);
    else if (key > node->key)
        node->right = insert(node->right, key);

    /* return the (unchanged) node pointer */
    return node;
}

int main() {
    /* Let us create the following BST
              50
           /     \
          30      70
         /  \    /  \
       20   40  60   80 */
    struct Node* root = (void*)0;
    root = insert(root, 50);
    insert(root, 30);
    insert(root, 20);
    insert(root, 40);
    insert(root, 70);
    insert(root, 60);
    insert(root, 80);

    // print in-order traversal of the BST
    printf("Inorder traversal: ");
    inorder(root);
    printf("\n");

    return 0;
}
