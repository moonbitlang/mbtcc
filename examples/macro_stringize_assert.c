#include "test.h"

int main() {
  // No spaces: clang's stringizing will produce "1+2", which we also target.
  ASSERT(3, 1+2);
  return 0;
}

