#include "test.h"

int fib(int n) {
  if (n <= 1) {
      return n;
  }
  return fib(n - 1) + fib(n - 2);
}

int main() {
  int n = 10; // Example input
  int result = fib(n);
  printf("%d\n", result); // Print the Fibonacci number for n
  return 0;
}
