#include "test.h"

int main() {
  int x = 42;
  int* p = &x;
  int y = *p;
  printf("%d\n", y);
  return 0;
}
