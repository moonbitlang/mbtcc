#include "test.h"

struct Point {
  int x;
  int y;
};

int sum_point_coords(struct Point *p) {
  return p->x + p->y;
}

int main() {
  struct Point p1;
  p1.x = 3;
  p1.y = 4;

  int z = sum_point_coords(&p1);
  printf("%d\n", z);
  return 0;
}

