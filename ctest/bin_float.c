void println_int(int);

int is_eqf(float a, float b) {
  int ia = *(int*)&a;
  int ib = *(int*)&b;
  return ia == ib;
}

int is_eqd(double a, double b) {
  long long ia = *(long long*)&a;
  long long ib = *(long long*)&b;
  return ia == ib;
}

int main() {
  float a = 1.5f, b = 3.0f, c = 4.5f;

  int passed = 0;
  passed += is_eqf(a + b, 4.5f);
  passed += is_eqf(c - b, 1.5f);
  passed += is_eqf(b - c, -1.5f);
  passed += is_eqf(a * b, 4.5f);
  passed += is_eqf(c / a, 3.0f);

  double x = 1.5, y = 3.0, z = 4.5;
  passed += is_eqd(x + y, 4.5);
  passed += is_eqd(z - y, 1.5);
  passed += is_eqd(y - z, -1.5);
  passed += is_eqd(x * y, 4.5);
  passed += is_eqd(z / x, 3.0);

  // cast
  passed += is_eqf(a * c, 6.75);
  passed += is_eqd(x * z, 6.75f);
  println_int(passed);
  return 0;
}