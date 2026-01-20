#include "test.h"

void copy(int *to, int *from, int count) {
    int n = (count + 7) / 8;
    switch (count % 8) {
        case 0: do { *to++ = *from++;
        case 7:      *to++ = *from++;
        case 6:      *to++ = *from++;
        case 5:      *to++ = *from++;
        case 4:      *to++ = *from++;
        case 3:      *to++ = *from++;
        case 2:      *to++ = *from++;
        case 1:      *to++ = *from++;
                } while (--n > 0);
    }
}

int main() {
    int from[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};
    int to[10] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    
    copy(to, from, 10);
    
    for (int i = 0; i < 10; i++) {
        printf("%d ", to[i]);
    }
    printf("\n");
    
    return 0;
}

