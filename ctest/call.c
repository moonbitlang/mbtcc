#include "test.h"


int ret42() {
    return 42;
}

int main () {
  int x = ret42();
  printf("%d\n", x);
  return 0;
}
