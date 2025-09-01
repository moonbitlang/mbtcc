#include "test.h"

int sum(int n) {
  int total = 0;
  for (int i = 0; i <= n; i++) {
    total += i;
  }
  return total;
}

int main() {
  int result = sum(10);
  printf("%d\n", result); // Expected: 55
  return 0;
}
