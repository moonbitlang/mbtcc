#include "test.h"

int main() {
  int x = 42;
  int* p = &x;
  int y = *p;
  printf("%d ", y);

  int a = 0x40400000;
  float *fa = (float *)&a;
  float v = *fa;
  int v2 = (int)v;
  printf("%d\n", v2);
  return 0;
}
