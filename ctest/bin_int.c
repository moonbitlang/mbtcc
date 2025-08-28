
int is_eq(int actual, int expected) {
  if (expected == actual) {
    return 1;
  }
  return 0;
}

int is_equ(unsigned int actual, unsigned int expected) {
  if (expected == actual) {
    return 1;
  }
  return 0;
}

int is_eql(long actual, long expected) {
  if (expected == actual) {
    return 1;
  }
  return 0;
}

int is_eqll(long long actual, long long expected) {
  if (expected == actual) {
    return 1;
  }
  return 0;
}

int is_equll(unsigned long long actual, unsigned long long expected) {
  if (expected == actual) {
    return 1;
  }
  return 0;
}

int main() {
  int passed = 0;

  int a = 5, b = 11;
  passed += is_eq(a + b, 16);
  passed += is_eq(a - b, -6);
  passed += is_eq(a * b, 55);
  passed += is_eq(b / a, 2);
  passed += is_eq(b % a, 1);
  passed += is_eq(a << 1, 10);
  passed += is_eq(b >> 1, 5);
  passed += is_eq(a & b, 1);
  passed += is_eq(a | b, 15);
  passed += is_eq(a ^ b, 14);

  unsigned int ua = 5, ub = 11;
  passed += is_equ(ua + ub, 16);
  passed += is_equ(ub - ua, 6);
  passed += is_equ(ua * ub, 55);
  passed += is_equ(ub / ua, 2);
  passed += is_equ(ub % ua, 1);
  passed += is_equ(ua << 1, 10);
  passed += is_equ(ub >> 1, 5);
  passed += is_equ(ua & ub, 1);
  passed += is_equ(ua | ub, 15);
  passed += is_equ(ua ^ ub, 14);

  long la = 5, lb = 11;
  passed += is_eql(la + lb, 16);
  passed += is_eql(la - lb, -6);
  passed += is_eql(la * lb, 55);
  passed += is_eql(lb / la, 2);
  passed += is_eql(lb % la, 1);
  passed += is_eql(la << 1, 10);
  passed += is_eql(lb >> 1, 5);
  passed += is_eql(la & lb, 1);
  passed += is_eql(la | lb, 15);
  passed += is_eql(la ^ lb, 14);

  long long lla = 5, llb = 11;
  passed += is_eqll(lla + llb, 16);
  passed += is_eqll(lla - llb, -6);
  passed += is_eqll(lla * llb, 55);
  passed += is_eqll(llb / lla, 2);
  passed += is_eqll(llb % lla, 1);
  passed += is_eqll(lla << 1, 10);
  passed += is_eqll(llb >> 1, 5);
  passed += is_eqll(lla & llb, 1);
  passed += is_eqll(lla | llb, 15);
  passed += is_eqll(lla ^ llb, 14);

  unsigned long long ulla = 5, ullb = 11;
  passed += is_equll(ulla + ullb, 16);
  passed += is_equll(ullb - ulla, 6);
  passed += is_equll(ulla * ullb, 55);
  passed += is_equll(ullb / ulla, 2);
  passed += is_equll(ullb % ulla, 1);
  passed += is_equll(ulla << 1, 10);
  passed += is_equll(ullb >> 1, 5);
  passed += is_equll(ulla & ullb, 1);
  passed += is_equll(ulla | ullb, 15);
  passed += is_equll(ulla ^ ullb, 14);

  return passed;
}
