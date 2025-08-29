
double sqrt(double x);
void println_int(int);

typedef struct {
  double real;
  double imag;
} Complex;

int main() {
  Complex c1 = { 3.0, 4.0 };

  double len = sqrt(c1.real * c1.real + c1.imag * c1.imag);

  int ilen = (int)len;
  println_int(ilen);

  return 0;
}
