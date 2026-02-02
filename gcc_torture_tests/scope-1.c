#include <stdlib.h>

int v = 3;

int f ()
{
  int v = 4;
  {
    extern int v;
    if (v != 3)
      abort ();
  }
}

int main ()
{
  f ();
  exit (0);
}
