#include "test.h"

typedef struct {
    int data[5];
    int size;
} ArrayStruct;

int main() {
    ArrayStruct s;
    s.data[0] = 10;
    s.data[1] = 20;
    s.data[2] = 30;
    s.size = 3;
    printf("data[0]=%d, data[1]=%d, data[2]=%d, size=%d\n", 
           s.data[0], s.data[1], s.data[2], s.size);
    return 0;
}
