#include "test.h"

// 测试指向 Union 的指针
union Value {
    int i;
    char c;
};

int main() {
    union Value val;
    union Value *ptr = &val;

    ptr->i = 65;
    printf("Value set via pointer (int): %d\n", ptr->i);
    printf("Value read via pointer (char): %c\n", ptr->c);

    val.c = 'B';
    printf("Value set directly (char): %c\n", val.c);
    printf("Value read via pointer (int): %d\n", ptr->i);

    return 0;
}

