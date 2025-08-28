void println_int(int);

int fib(int n) {
  if (n <= 1) {
      return n;
  }
  return fib(n - 1) + fib(n - 2);
}

int main() {
  int n = 10; // Example input
  int result = fib(n);
  println_int(result); // Print the Fibonacci number for n
  return 0;
}