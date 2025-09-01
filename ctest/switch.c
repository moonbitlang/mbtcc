
void println_int(int x);

int foo(int a) {
  switch (a) {
    case 1: return 100;
    case 2: return 200;
    case 3: return 300;
    case 4: return 400;
    default: return -100;
  }
}

int main() {
  int r1 = foo(1);
  int r2 = foo(2);
  int r3 = foo(3);
  int r4 = foo(4);

  int r = r1 + r2 + r3 + r4;
  println_int(r);

  return 0;
}
