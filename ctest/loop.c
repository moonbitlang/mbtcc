#include "test.h"

int sum_for(int n) {
  int total = 0;
  for (int i = 0; i <= n; i++) {
    total += i;
  }
  return total;
}

int sum_while(int n) {
  int total = 0;
  int i = 0;
  while (i <= n) {
    total += i;
    i += 1;
  }
  return total;
}

int sum_dowhile(int n) {
    int s = 0;
    do {
        s += n;
        n--;
    } while (n > 0);
    return s;
}

int main() {
  int result_for = sum_for(10);
  printf("%d ", result_for); // Expected: 55
  int result_while = sum_while(10);
  printf("%d ", result_while); // Expected: 55
  int result_dowhile = sum_dowhile(10);
  printf("%d\n", result_dowhile); // Expected: 55
  return 0;
}
