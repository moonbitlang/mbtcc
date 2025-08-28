void println_int(int x);

struct Point {
  int x;
  int y;
};

int sum_point_coords(struct Point *p) {
  return p->x + p->y;
}

int main() {
  struct Point p1 = { .x = 3, .y = 4 };

  int z = sum_point_coords(&p1);
  println_int(z);
  return 0;
}


