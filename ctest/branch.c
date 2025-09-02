#include "test.h"

int max(int a, int b) {
  int res;
  if (a > b) {
    res = a;
  } else {
    res = b;
  }
  return res;
}

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

int foo2(int a) {
  switch (a) {
    case 1: return 100;
    case 2: return 200;
    case 3: return 300;
    case 4: return 400;
    default: return -100;
  }
}

int main () {
  int res = max(3, 5);
  printf("%d ", res);

  int x = foo(150, 30);
  int y = foo(250, 10);
  printf("%d ", x + y);

  int r1 = foo2(1);
  int r2 = foo2(2);
  int r3 = foo2(3);
  int r4 = foo2(4);

  int r = r1 + r2 + r3 + r4;
  printf("%d\n", r);
  return 0;
}
