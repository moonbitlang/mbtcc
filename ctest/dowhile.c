#include "test.h"


int sum(int n) {
    int s = 0;
    do {
        s += n;
        n--;
    } while (n > 0);
    return s;
}

int main() {
  printf("%d\n", sum(10)); // Expected: 55
  return 0;
}
