
void println_int(int x);

struct Point {
  int x;
  int y;
};

int main() {
  struct Point p1;
  p1.x = 3;
  p1.y = 4;

  int z = p1.x + p1.y;
  println_int(z);
  return 0;
}
