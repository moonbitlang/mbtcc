
float sqrtf(float x);
double sqrt(double x);
void print_int(int x);
void println_int(int x);

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
  print_int((int)diag);

  struct Position p = rect.pos;
  int dist = (int)sqrt((double)(p.x * p.x + p.y * p.y));
  println_int(dist);

  return 0;
}
