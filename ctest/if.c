void print_int(int x);

int max(int a, int b) {
  if (a > b) {
    return a;
  } else {
    return b;
  }
}

int min(int a, int b) {
  if (a < b) {
    return a;
  } else {
    return b;
  }
}

int main() {
  int a = 10;
  int b = 20;
  int c = max(a, b);
  int d = min(a, b);
  int diff = c - d;
  print_int(diff); // Should print 10
  return 0;
}
