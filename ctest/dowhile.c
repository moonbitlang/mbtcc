void println_int(int);

int sum(int n) {
    int s = 0;
    do {
        s += n;
        n--;
    } while (n > 0);
    return s;
}

int main() {
  println_int(sum(10)); // Expected: 55
  return 0;
}