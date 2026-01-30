#include "test.h"

// 测试最基本的union，验证内存共享
union Data {
    int i;
    float f;
    char str[20];
};

int main() {
    union Data data;

    printf("Memory size occupied by data : %d\n", (int)sizeof(data));

    data.i = 10;
    printf("data.i : %d\n", data.i);

    data.f = 220.5;
    printf("data.f : %f\n", data.f);
    // data.i 现在应该是无意义的（或者是float的位表示）
    printf("data.i after setting f : %d\n", data.i);

    // 简单的字符串操作
    data.str[0] = 'H';
    data.str[1] = 'i';
    data.str[2] = '\0';
    printf("data.str : %s\n", data.str);

    return 0;
}

