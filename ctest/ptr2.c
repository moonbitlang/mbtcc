#include "test.h"

int main() {
  int a = 0x40400000;
  float *p = (float *)&a;
  float v = *p;
  int v2 = (int)v;
  printf("%d\n", v2);
  return 0;
}
