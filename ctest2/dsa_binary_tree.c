#include "test.h"

// 二叉树实现
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

// Tree traversal functions
void preorder(struct TreeNode* root) {
    if (root != NULL) {
        printf("%d ", root->val);
        preorder(root->left);
        preorder(root->right);
    }
}

void inorder(struct TreeNode* root) {
    if (root != NULL) {
        inorder(root->left);
        printf("%d ", root->val);
        inorder(root->right);
    }
}

void postorder(struct TreeNode* root) {
    if (root != NULL) {
        postorder(root->left);
        postorder(root->right);
        printf("%d ", root->val);
    }
}

// Tree operations
int tree_height(struct TreeNode* root) {
    if (root == NULL) {
        return 0;
    }
    
    int left_height = tree_height(root->left);
    int right_height = tree_height(root->right);
    
    return (left_height > right_height ? left_height : right_height) + 1;
}

int count_nodes(struct TreeNode* root) {
    if (root == NULL) {
        return 0;
    }
    return 1 + count_nodes(root->left) + count_nodes(root->right);
}

void free_tree(struct TreeNode* root) {
    if (root != NULL) {
        free_tree(root->left);
        free_tree(root->right);
        free(root);
    }
}

// Level order traversal using queue
#define MAX_QUEUE_SIZE 100

struct Queue {
    struct TreeNode* items[MAX_QUEUE_SIZE];
    int front;
    int rear;
};

void init_queue(struct Queue* q) {
    q->front = q->rear = -1;
}

void enqueue(struct Queue* q, struct TreeNode* node) {
    if (q->rear == MAX_QUEUE_SIZE - 1) {
        return;
    }
    if (q->front == -1) {
        q->front = 0;
    }
    q->rear++;
    q->items[q->rear] = node;
}

struct TreeNode* dequeue(struct Queue* q) {
    if (q->front == -1) {
        return NULL;
    }
    struct TreeNode* node = q->items[q->front];
    if (q->front == q->rear) {
        q->front = q->rear = -1;
    } else {
        q->front++;
    }
    return node;
}

void level_order(struct TreeNode* root) {
    if (root == NULL) return;
    
    struct Queue q;
    init_queue(&q);
    enqueue(&q, root);
    
    while (q.front != -1) {
        struct TreeNode* node = dequeue(&q);
        printf("%d ", node->val);
        
        if (node->left != NULL) {
            enqueue(&q, node->left);
        }
        if (node->right != NULL) {
            enqueue(&q, node->right);
        }
    }
}

int main() {
    // Create a sample binary tree
    struct TreeNode* root = create_node(1);
    root->left = create_node(2);
    root->right = create_node(3);
    root->left->left = create_node(4);
    root->left->right = create_node(5);
    root->right->left = create_node(6);
    root->right->right = create_node(7);
    
    printf("Tree traversals:\n");
    printf("Preorder: ");
    preorder(root);
    printf("\n");
    
    printf("Inorder: ");
    inorder(root);
    printf("\n");
    
    printf("Postorder: ");
    postorder(root);
    printf("\n");
    
    printf("Level order: ");
    level_order(root);
    printf("\n");
    
    printf("\nTree properties:\n");
    printf("Height: %d\n", tree_height(root));
    printf("Number of nodes: %d\n", count_nodes(root));
    
    // Cleanup
    free_tree(root);
    
    return 0;
}
