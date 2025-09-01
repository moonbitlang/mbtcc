
#include "test.h"

int main() {
  double a[5] = { 1.0, 3., 5, 7e+0, 9, };

  double sum = 0.0;
  for (int i = 0; i < 5; i++) {
    sum += a[i];
  }
  printf("%lf\n", sum);
  return 0;
}
