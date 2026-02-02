#include <stdlib.h>

double f (double a) {}
double (* const a[]) (double) = {&f};

int main ()
{
  double (*p) ();
  p = &f;
  if (p != a[0])
    abort ();
  exit (0);
}
