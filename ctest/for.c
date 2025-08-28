
int sum(int n) {
  int total = 0;
  for (int i = 0; i <= n; i++) {
    total += i;
  }
  return total;
}

int main() {
  int result = sum(10);
  return result; // Expected: 55
}
