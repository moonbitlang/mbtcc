
double sqrt(double);
void println_int(int);

struct Point {
  double x, y;
};

double length(struct Point *p) {
  return sqrt(p->x * p->x + p->y * p->y);
}

int main() {
  struct Point arr[2] = { { .x = 5.0, .y = 12.0 }, { .x = 3.0, .y = 4.0 } };

  double len1 = length(&arr[0]);
  double len2 = length(&arr[1]);
  double total = len1 + len2;

  int itotal = (int)total;
  println_int(itotal);

  return 0;
}
