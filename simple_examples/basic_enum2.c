#include "test.h"

// 测试带有自定义值的 enum
enum Status {
    OK = 0,
    ERROR = -1,
    WARNING = 1,
    UNKNOWN = 99
};

int main() {
    enum Status s = OK;
    printf("Status OK: %d\n", s);

    s = ERROR;
    printf("Status ERROR: %d\n", s);

    s = WARNING;
    printf("Status WARNING: %d\n", s);

    s = UNKNOWN;
    printf("Status UNKNOWN: %d\n", s);

    return 0;
}

