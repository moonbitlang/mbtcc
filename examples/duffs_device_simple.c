#include "test.h"

int main() {
    int count = 10;
    int n = (count + 7) / 8;
    int result = 0;
    
    switch (count % 8) {
        case 0: do { result = result + 1;
        case 7:      result = result + 1;
        case 6:      result = result + 1;
        case 5:      result = result + 1;
        case 4:      result = result + 1;
        case 3:      result = result + 1;
        case 2:      result = result + 1;
        case 1:      result = result + 1;
                } while (--n > 0);
    }
    
    printf("Result: %d\n", result);
    return 0;
}

