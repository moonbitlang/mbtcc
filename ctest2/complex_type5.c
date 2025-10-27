#include "test.h"

// 测试复杂的自定义类型系统
typedef struct TypeInfo TypeInfo;
typedef struct Value Value;

// Type system definitions
enum ValueType {
    TYPE_INT,
    TYPE_FLOAT,
    TYPE_STRING,
    TYPE_ARRAY,
    TYPE_STRUCT
};

struct TypeInfo {
    enum ValueType type;
    char* name;
    int size;
    union {
        // For array type
        struct {
            TypeInfo* element_type;
            int length;
        } array_info;
        // For struct type
        struct {
            TypeInfo** field_types;
            char** field_names;
            int field_count;
        } struct_info;
    } info;
};

struct Value {
    TypeInfo* type;
    union {
        int int_val;
        float float_val;
        char* string_val;
        Value* array_vals;
        Value** struct_vals;
    } data;
};

// Type system operations
TypeInfo* create_primitive_type(enum ValueType type, char* name, int size) {
    TypeInfo* info = (TypeInfo*)malloc(sizeof(TypeInfo));
    info->type = type;
    info->name = name;
    info->size = size;
    return info;
}

TypeInfo* create_array_type(TypeInfo* element_type, int length) {
    TypeInfo* info = (TypeInfo*)malloc(sizeof(TypeInfo));
    info->type = TYPE_ARRAY;
    info->name = "array";
    info->size = element_type->size * length;
    info->info.array_info.element_type = element_type;
    info->info.array_info.length = length;
    return info;
}

TypeInfo* create_struct_type(char* name, char** field_names, 
                           TypeInfo** field_types, int field_count) {
    TypeInfo* info = (TypeInfo*)malloc(sizeof(TypeInfo));
    info->type = TYPE_STRUCT;
    info->name = name;
    info->info.struct_info.field_names = field_names;
    info->info.struct_info.field_types = field_types;
    info->info.struct_info.field_count = field_count;
    
    // Calculate total size
    int total_size = 0;
    for (int i = 0; i < field_count; i++) {
        total_size += field_types[i]->size;
    }
    info->size = total_size;
    
    return info;
}

void print_type_info(TypeInfo* type) {
    printf("Type: %s, Size: %d bytes\n", type->name, type->size);
    
    if (type->type == TYPE_ARRAY) {
        printf("Array length: %d\n", type->info.array_info.length);
        printf("Element type: %s\n", type->info.array_info.element_type->name);
    }
    else if (type->type == TYPE_STRUCT) {
        printf("Fields:\n");
        for (int i = 0; i < type->info.struct_info.field_count; i++) {
            printf("  %s: %s\n",
                   type->info.struct_info.field_names[i],
                   type->info.struct_info.field_types[i]->name);
        }
    }
}

int main() {
    // Create primitive types
    TypeInfo* int_type = create_primitive_type(TYPE_INT, "int", sizeof(int));
    TypeInfo* float_type = create_primitive_type(TYPE_FLOAT, "float", sizeof(float));
    TypeInfo* string_type = create_primitive_type(TYPE_STRING, "string", sizeof(char*));
    
    printf("Primitive types:\n");
    print_type_info(int_type);
    print_type_info(float_type);
    print_type_info(string_type);
    
    // Create array type
    TypeInfo* int_array_type = create_array_type(int_type, 10);
    printf("\nArray type:\n");
    print_type_info(int_array_type);
    
    // Create struct type
    char* field_names[] = {"name", "age", "scores"};
    TypeInfo* field_types[] = {string_type, int_type, int_array_type};
    TypeInfo* student_type = create_struct_type("Student", field_names, 
                                              field_types, 3);
    
    printf("\nStruct type:\n");
    print_type_info(student_type);
    
    // Free allocated memory
    free(int_type);
    free(float_type);
    free(string_type);
    free(int_array_type);
    free(student_type);
    
    return 0;
}
