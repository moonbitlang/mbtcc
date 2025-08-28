void println_int(int);

int main() {
  int a = 5, b = 11;
  int result = a + b - a * b / a % b;
  result = result & b;
  result = result | a;
  result = result ^ b;
  result = result << 1;
  result = result >> 1;
  if (a != b) {
    result = result + 1;
  }
  println_int(result);
  return 0;
}