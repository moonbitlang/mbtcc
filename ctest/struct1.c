
#include "test.h"

struct Point {
  int x;
  int y;
};

int main() {
  struct Point p1;
  p1.x = 3;
  p1.y = 4;

  int z = p1.x + p1.y;
  printf("%d\n", z); // Should print 7
  return 0;
}
