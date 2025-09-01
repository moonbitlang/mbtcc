#include "test.h"

int foo(int a, int b) {
  int res;
  if (a > 100 && a < 200) {
    if (b > 50 || b < 20) {
      res = a + b;
    } else {
      res = a - b;
    }
  } else {
    res = a * b;
  }
  return res;
}

int main() {
  int x = foo(150, 30);
  int y = foo(250, 10);
  printf("%d\n", x + y);
  return 0;
}
