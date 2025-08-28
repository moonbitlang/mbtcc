void println_int(int);

int max(int a, int b) {
  int res;
  if (a > b) {
    res = a;
  } else {
    res = b;
  }
  return res;
}

int main () {
  int res = max(3, 5);
  println_int(res);
  return 0;
}