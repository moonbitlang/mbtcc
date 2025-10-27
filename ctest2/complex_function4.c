#include "test.h"

// 测试函数的动态调用和状态管理
typedef struct {
    int id;
    char* name;
    int (*process)(void*);
    void* data;
} Task;

typedef struct {
    Task* tasks;
    int capacity;
    int size;
} TaskQueue;

// Task processing functions
int process_number(void* data) {
    int* num = (int*)data;
    printf("Processing number: %d\n", *num);
    return *num * 2;
}

int process_string(void* data) {
    char* str = (char*)data;
    printf("Processing string: %s\n", str);
    return strlen(str);
}

// Task queue operations
TaskQueue* create_task_queue(int capacity) {
    TaskQueue* queue = (TaskQueue*)malloc(sizeof(TaskQueue));
    queue->tasks = (Task*)malloc(capacity * sizeof(Task));
    queue->capacity = capacity;
    queue->size = 0;
    return queue;
}

void add_task(TaskQueue* queue, int id, char* name, 
              int (*process)(void*), void* data) {
    if (queue->size < queue->capacity) {
        Task task = {id, name, process, data};
        queue->tasks[queue->size++] = task;
    }
}

int execute_task(Task* task) {
    printf("Executing task %d (%s):\n", task->id, task->name);
    return task->process(task->data);
}

void process_task_queue(TaskQueue* queue) {
    printf("Processing task queue with %d tasks:\n", queue->size);
    for (int i = 0; i < queue->size; i++) {
        int result = execute_task(&queue->tasks[i]);
        printf("Task %d result: %d\n\n", queue->tasks[i].id, result);
    }
}

void free_task_queue(TaskQueue* queue) {
    free(queue->tasks);
    free(queue);
}

// Task generator function
void generate_tasks(TaskQueue* queue) {
    // Number processing tasks
    int* numbers = (int*)malloc(3 * sizeof(int));
    numbers[0] = 10;
    numbers[1] = 20;
    numbers[2] = 30;
    
    for (int i = 0; i < 3; i++) {
        add_task(queue, i + 1, "Number Task", process_number, &numbers[i]);
    }
    
    // String processing tasks
    char* strings[] = {"Hello", "World", "Test"};
    for (int i = 0; i < 3; i++) {
        add_task(queue, i + 4, "String Task", process_string, strings[i]);
    }
}

int main() {
    // Create and initialize task queue
    TaskQueue* queue = create_task_queue(10);
    
    // Generate and add tasks
    generate_tasks(queue);
    
    // Process all tasks
    process_task_queue(queue);
    
    // Cleanup
    free_task_queue(queue);
    
    return 0;
}
