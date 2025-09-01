
#include "test.h"

typedef struct {
  double real;
  double imag;
} Complex;

int main() {
  Complex c1 = { 3.0, 4.0 };

  double len = sqrt(c1.real * c1.real + c1.imag * c1.imag);

  int ilen = (int)len;
  printf("%d\n", ilen);

  return 0;
}
