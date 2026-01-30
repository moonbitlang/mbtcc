#include "test.h"

// 测试函数的链式调用和管道处理
typedef struct {
    void* data;
    void* (*transform)(void*);
    void (*cleanup)(void*);
} Pipeline;

// Data structures
typedef struct {
    int* values;
    int size;
} IntArray;

typedef struct {
    float* values;
    int size;
} FloatArray;

typedef struct {
    char** values;
    int size;
} StringArray;

// Memory management functions
IntArray* create_int_array(int size) {
    IntArray* arr = (IntArray*)malloc(sizeof(IntArray));
    arr->values = (int*)malloc(size * sizeof(int));
    arr->size = size;
    return arr;
}

FloatArray* create_float_array(int size) {
    FloatArray* arr = (FloatArray*)malloc(sizeof(FloatArray));
    arr->values = (float*)malloc(size * sizeof(float));
    arr->size = size;
    return arr;
}

void cleanup_int_array(void* data) {
    IntArray* arr = (IntArray*)data;
    free(arr->values);
    free(arr);
}

void cleanup_float_array(void* data) {
    FloatArray* arr = (FloatArray*)data;
    free(arr->values);
    free(arr);
}

// Transform functions
void* double_values(void* data) {
    IntArray* input = (IntArray*)data;
    IntArray* output = create_int_array(input->size);
    
    for (int i = 0; i < input->size; i++) {
        output->values[i] = input->values[i] * 2;
    }
    
    return output;
}

void* to_float(void* data) {
    IntArray* input = (IntArray*)data;
    FloatArray* output = create_float_array(input->size);
    
    for (int i = 0; i < input->size; i++) {
        output->values[i] = (float)input->values[i];
    }
    
    return output;
}

void* square_float(void* data) {
    FloatArray* input = (FloatArray*)data;
    FloatArray* output = create_float_array(input->size);
    
    for (int i = 0; i < input->size; i++) {
        output->values[i] = input->values[i] * input->values[i];
    }
    
    return output;
}

// Pipeline operations
Pipeline* create_pipeline(void* initial_data, 
                        void* (*transform)(void*),
                        void (*cleanup)(void*)) {
    Pipeline* pipeline = (Pipeline*)malloc(sizeof(Pipeline));
    pipeline->data = initial_data;
    pipeline->transform = transform;
    pipeline->cleanup = cleanup;
    return pipeline;
}

Pipeline* pipe(Pipeline* previous, 
              void* (*transform)(void*),
              void (*cleanup)(void*)) {
    void* result = transform(previous->data);
    previous->cleanup(previous->data);
    free(previous);
    
    return create_pipeline(result, transform, cleanup);
}

void* execute_pipeline(Pipeline* pipeline) {
    void* result = pipeline->data;
    free(pipeline);
    return result;
}

// Printing functions
void print_int_array(IntArray* arr) {
    printf("Int Array: ");
    for (int i = 0; i < arr->size; i++) {
        printf("%d ", arr->values[i]);
    }
    printf("\n");
}

void print_float_array(FloatArray* arr) {
    printf("Float Array: ");
    for (int i = 0; i < arr->size; i++) {
        printf("%.2f ", arr->values[i]);
    }
    printf("\n");
}

int main() {
    // Create initial data
    IntArray* initial = create_int_array(5);
    for (int i = 0; i < 5; i++) {
        initial->values[i] = i + 1;
    }
    
    printf("Initial ");
    print_int_array(initial);
    
    // Create and execute pipeline
    Pipeline* pipeline = create_pipeline(initial, double_values, cleanup_int_array);
    
    // Double the values
    IntArray* doubled = (IntArray*)pipeline->data;
    printf("After doubling ");
    print_int_array(doubled);
    
    // Convert to float
    pipeline = pipe(pipeline, to_float, cleanup_int_array);
    FloatArray* floats = (FloatArray*)pipeline->data;
    printf("After conversion to float ");
    print_float_array(floats);
    
    // Square the values
    pipeline = pipe(pipeline, square_float, cleanup_float_array);
    FloatArray* result = (FloatArray*)execute_pipeline(pipeline);
    printf("Final result after squaring ");
    print_float_array(result);
    
    // Cleanup final result
    cleanup_float_array(result);
    
    return 0;
}
