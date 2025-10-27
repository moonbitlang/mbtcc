#include "test.h"

// 测试结构体数组
struct Student {
    int id;
    int score;
};

// 测试结构体嵌套
struct Class {
    int class_id;
    struct Student students[3];
};

int main() {
    struct Student class1[3];
    
    // Initialize array of structures
    for (int i = 0; i < 3; i++) {
        class1[i].id = i + 1;
        class1[i].score = 80 + i * 5;
    }
    
    // Print array of structures
    printf("Student records:\n");
    for (int i = 0; i < 3; i++) {
        printf("ID: %d, Score: %d\n", 
               class1[i].id, 
               class1[i].score);
    }
    
    // Test nested structure
    struct Class c;
    c.class_id = 101;
    
    for (int i = 0; i < 3; i++) {
        c.students[i].id = i + 10;
        c.students[i].score = 75 + i * 5;
    }
    
    printf("\nClass %d records:\n", c.class_id);
    for (int i = 0; i < 3; i++) {
        printf("ID: %d, Score: %d\n",
               c.students[i].id,
               c.students[i].score);
    }
    
    return 0;
}
