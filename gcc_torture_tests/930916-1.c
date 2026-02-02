#include <stdlib.h>

int f (n)
     unsigned n;
{
  if ((int) n >= 0)
    abort ();
}

int main ()
{
  unsigned x = ~0;
  f (x);
  exit (0);
}
