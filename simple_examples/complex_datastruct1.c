#include "test.h"

// 复合数据结构 1: Tagged Union
// 使用 Enum 标识 Union 中当前存储的数据类型

typedef enum {
    TYPE_INT,
    TYPE_FLOAT,
    TYPE_STRING
} ValueType;

typedef struct {
    ValueType type;
    union {
        int i;
        float f;
        char* s;
    } data;
} TypedValue;

void print_typed_value(TypedValue* v) {
    switch (v->type) {
        case TYPE_INT:
            printf("Integer: %d\n", v->data.i);
            break;
        case TYPE_FLOAT:
            printf("Float: %f\n", v->data.f);
            break;
        case TYPE_STRING:
            printf("String: %s\n", v->data.s);
            break;
    }
}

int main() {
    TypedValue v1;
    v1.type = TYPE_INT;
    v1.data.i = 123;
    
    TypedValue v2;
    v2.type = TYPE_FLOAT;
    v2.data.f = 45.67;
    
    TypedValue v3;
    v3.type = TYPE_STRING;
    v3.data.s = "Hello World";
    
    print_typed_value(&v1);
    print_typed_value(&v2);
    print_typed_value(&v3);
    
    return 0;
}
