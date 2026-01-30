#include "test.h"

// 最大堆实现
#define MAX_HEAP_SIZE 100

struct MaxHeap {
    int arr[MAX_HEAP_SIZE];
    int size;
};

void init_heap(struct MaxHeap* heap) {
    heap->size = 0;
}

void swap(int* a, int* b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}

void heapify_up(struct MaxHeap* heap, int index) {
    int parent = (index - 1) / 2;
    
    while (index > 0 && heap->arr[parent] < heap->arr[index]) {
        swap(&heap->arr[parent], &heap->arr[index]);
        index = parent;
        parent = (index - 1) / 2;
    }
}

void heapify_down(struct MaxHeap* heap, int index) {
    int largest = index;
    int left = 2 * index + 1;
    int right = 2 * index + 2;
    
    if (left < heap->size && heap->arr[left] > heap->arr[largest]) {
        largest = left;
    }
    
    if (right < heap->size && heap->arr[right] > heap->arr[largest]) {
        largest = right;
    }
    
    if (largest != index) {
        swap(&heap->arr[index], &heap->arr[largest]);
        heapify_down(heap, largest);
    }
}

void insert(struct MaxHeap* heap, int value) {
    if (heap->size >= MAX_HEAP_SIZE) {
        printf("Heap overflow\n");
        return;
    }
    
    heap->arr[heap->size] = value;
    heapify_up(heap, heap->size);
    heap->size++;
}

int extract_max(struct MaxHeap* heap) {
    if (heap->size <= 0) {
        printf("Heap underflow\n");
        return -1;
    }
    
    int max = heap->arr[0];
    heap->arr[0] = heap->arr[heap->size - 1];
    heap->size--;
    heapify_down(heap, 0);
    
    return max;
}

int get_max(struct MaxHeap* heap) {
    if (heap->size <= 0) {
        printf("Heap is empty\n");
        return -1;
    }
    return heap->arr[0];
}

void print_heap(struct MaxHeap* heap) {
    printf("Heap: ");
    for (int i = 0; i < heap->size; i++) {
        printf("%d ", heap->arr[i]);
    }
    printf("\n");
}

// Test heap sort using the max heap
void heap_sort(int arr[], int n) {
    struct MaxHeap heap;
    init_heap(&heap);
    
    // Insert all elements into the heap
    for (int i = 0; i < n; i++) {
        insert(&heap, arr[i]);
    }
    
    // Extract elements from the heap in descending order
    for (int i = n - 1; i >= 0; i--) {
        arr[i] = extract_max(&heap);
    }
}

int main() {
    struct MaxHeap heap;
    init_heap(&heap);
    
    // Test insertion
    printf("Testing heap insertion:\n");
    insert(&heap, 45);
    insert(&heap, 20);
    insert(&heap, 14);
    insert(&heap, 12);
    insert(&heap, 31);
    insert(&heap, 7);
    insert(&heap, 11);
    insert(&heap, 13);
    insert(&heap, 7);
    
    print_heap(&heap);
    
    // Test maximum element
    printf("\nMaximum element: %d\n", get_max(&heap));
    
    // Test extract max
    printf("\nExtracting maximum elements:\n");
    for (int i = 0; i < 3; i++) {
        printf("Extracted: %d\n", extract_max(&heap));
        print_heap(&heap);
    }
    
    // Test heap sort
    printf("\nTesting heap sort:\n");
    int arr[] = {12, 11, 13, 5, 6, 7};
    int n = sizeof(arr) / sizeof(arr[0]);
    
    printf("Original array: ");
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
    
    heap_sort(arr, n);
    
    printf("Sorted array: ");
    for (int i = 0; i < n; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");
    
    return 0;
}
