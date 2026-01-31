// rdar://8453812
extern void abort();

int getComplex(int val) {
  static int count;
  if (count++)
    abort();
  return val;
}

int doo() {
    int cond;
    int rhs = 0;

    return getComplex(1) ? : rhs;
}

int main() {
  doo();
  return 0;
}
