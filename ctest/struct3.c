#include "test.h"

struct Position {
  int x;
  int y;
};

struct FRect {
  struct Position pos;
  float width;
  float height;
};


int main() {
  struct FRect rect;
  rect.pos.x = 3;
  rect.pos.y = 4;
  rect.width = 5.0;
  rect.height = 6.0;

  float diag = sqrtf(rect.width * rect.width + rect.height * rect.height);
  printf("%d\n", (int)diag);

  struct Position p = rect.pos;
  int dist = (int)sqrt((double)(p.x * p.x + p.y * p.y));
  printf("%d\n", dist);

  return 0;
}
