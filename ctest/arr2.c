void println_int(int);

int main() {
  int arr[5] = {1, 2, 3, 4, 5};

  int total = 0;
  for (int i = 0; i < 5; i++) {
    total += arr[i];
  }
  println_int(total); // Should print 15
  return 0;
}