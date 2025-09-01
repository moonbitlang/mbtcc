#include "test.h"

int main() {
  int a = 5;
  a++;

  int b = 5;
  ++b;

  int c = 5;
  c--;

  int d = 5;
  --d;
  printf("%d\n", a + b + c + d);
  return 0;
}
