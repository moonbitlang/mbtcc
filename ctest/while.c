#include "test.h"

int sum(int n) {
  int total = 0;
  int i = 0;
  while (i <= n) {
    total += i;
    i += 1;
  }
  return total;
}

int main() {
  int result = sum(10);
  printf("%d\n", result); // Expected: 55
  return 0;
}
