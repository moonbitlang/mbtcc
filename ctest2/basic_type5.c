#include "test.h"

// 测试结构体、联合体和枚举的组合使用
enum Type {
    INT_TYPE,
    FLOAT_TYPE,
    CHAR_TYPE
};

union Value {
    int i;
    float f;
    char c;
};

struct Variable {
    enum Type type;
    union Value value;
};

int main() {
    struct Variable vars[3];
    
    // Integer variable
    vars[0].type = INT_TYPE;
    vars[0].value.i = 42;
    
    // Float variable
    vars[1].type = FLOAT_TYPE;
    vars[1].value.f = 3.14f;
    
    // Char variable
    vars[2].type = CHAR_TYPE;
    vars[2].value.c = 'A';
    
    // Print variables based on their types
    for (int i = 0; i < 3; i++) {
        printf("Variable %d: ", i);
        switch (vars[i].type) {
            case INT_TYPE:
                printf("Integer = %d\n", vars[i].value.i);
                break;
            case FLOAT_TYPE:
                printf("Float = %f\n", vars[i].value.f);
                break;
            case CHAR_TYPE:
                printf("Char = %c\n", vars[i].value.c);
                break;
        }
    }
    
    return 0;
}
