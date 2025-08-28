void println_int(int);

int main() {
  int x = 42;
  int* p = &x;
  int y = *p;
  println_int(y);
  return 0;
}