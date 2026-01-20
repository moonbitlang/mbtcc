#include "test.h"

int main() {
  // GNU statement expression
  int v = ({ int x = 3; x + 2; });
  printf("%d\n", v);
  return 0;
}

