

int fib(int n) {
  if (n <= 1) {
      return n;
  }
  return fib(n - 1) + fib(n - 2);
}

int main() {
  int n = 10; // Example input
  int result = fib(n);
  return result; // Return the Fibonacci number for n
}
