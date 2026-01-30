#include "test.h"

// 二叉搜索树实现
struct TreeNode {
    int val;
    struct TreeNode* left;
    struct TreeNode* right;
};

struct TreeNode* create_node(int value) {
    struct TreeNode* node = (struct TreeNode*)malloc(sizeof(struct TreeNode));
    node->val = value;
    node->left = NULL;
    node->right = NULL;
    return node;
}

// BST operations
struct TreeNode* insert(struct TreeNode* root, int value) {
    if (root == NULL) {
        return create_node(value);
    }
    
    if (value < root->val) {
        root->left = insert(root->left, value);
    } else if (value > root->val) {
        root->right = insert(root->right, value);
    }
    
    return root;
}

struct TreeNode* find_min(struct TreeNode* root) {
    while (root->left != NULL) {
        root = root->left;
    }
    return root;
}

struct TreeNode* delete(struct TreeNode* root, int value) {
    if (root == NULL) {
        return root;
    }
    
    if (value < root->val) {
        root->left = delete(root->left, value);
    } else if (value > root->val) {
        root->right = delete(root->right, value);
    } else {
        // Node with only one child or no child
        if (root->left == NULL) {
            struct TreeNode* temp = root->right;
            free(root);
            return temp;
        } else if (root->right == NULL) {
            struct TreeNode* temp = root->left;
            free(root);
            return temp;
        }
        
        // Node with two children
        struct TreeNode* temp = find_min(root->right);
        root->val = temp->val;
        root->right = delete(root->right, temp->val);
    }
    return root;
}

struct TreeNode* search(struct TreeNode* root, int value) {
    if (root == NULL || root->val == value) {
        return root;
    }
    
    if (value < root->val) {
        return search(root->left, value);
    }
    return search(root->right, value);
}

void inorder(struct TreeNode* root) {
    if (root != NULL) {
        inorder(root->left);
        printf("%d ", root->val);
        inorder(root->right);
    }
}

int is_bst(struct TreeNode* root, int min, int max) {
    if (root == NULL) {
        return 1;
    }
    
    if (root->val < min || root->val > max) {
        return 0;
    }
    
    return is_bst(root->left, min, root->val - 1) &&
           is_bst(root->right, root->val + 1, max);
}

void free_tree(struct TreeNode* root) {
    if (root != NULL) {
        free_tree(root->left);
        free_tree(root->right);
        free(root);
    }
}

int main() {
    struct TreeNode* root = NULL;
    
    // Test insertion
    printf("Inserting values: 50, 30, 70, 20, 40, 60, 80\n");
    root = insert(root, 50);
    insert(root, 30);
    insert(root, 70);
    insert(root, 20);
    insert(root, 40);
    insert(root, 60);
    insert(root, 80);
    
    printf("Inorder traversal: ");
    inorder(root);
    printf("\n");
    
    // Test search
    int search_value = 40;
    struct TreeNode* result = search(root, search_value);
    printf("\nSearching for %d: %s\n", search_value,
           result != NULL ? "Found" : "Not found");
    
    // Test BST property
    printf("Is BST: %s\n", is_bst(root, -2147483648, 2147483647) ?
           "Yes" : "No");
    
    // Test deletion
    printf("\nDeleting 30\n");
    root = delete(root, 30);
    printf("Inorder traversal after deletion: ");
    inorder(root);
    printf("\n");
    
    // Cleanup
    free_tree(root);
    
    return 0;
}
